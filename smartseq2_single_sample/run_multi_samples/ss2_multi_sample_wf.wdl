import ss2_single_sample.wdl as singlesample
task GatherMetricsBySample {
  File rna_metrics_fn
  File aln_metrics_fn
  File insert_metrics_fn
  File dup_metrics_fn

  command <<<
    mkdir gathers
    cat ${rna_metrics_fn} |/root/google-cloud-sdk/bin/gsutil -m cp -L cp.log -I gathers/
    cat ${rna_metrics_fn} | rev | cut -d '/' -f 1 | rev | awk '{print "gathers/" $1}' > inputs.list
    
    python3 <<CODE
    for line in open('inputs.list'):
        try:
            fn=open(line.strip('\n'),'r')
            print(fn.readlines())
        except Exception as e:
          raise e
          print("No file found"+line)
    CODE
  >>>
  
  output {
    File rna_metrics = write_lines(stdout())
  }
  runtime {
    docker: "broadinstitute/genomes-in-the-cloud:2.3.1-1504795437"
    memory: "4 GB"
    disks: "local-disk 10 HDD"
  }
}

import ss2_single_sample.wdl

workflow Ss2RunMultiSample {
  File sra_list_file
  File gtf
  File ref_fasta
  File rrna_interval
  File ref_flat
  String star_genome
  String rsem_genome
  String sra_dir
  
## start to scatter single sample workflow by sraID
  Array[String] sraIDs=read_lines(sra_list_file)
   
  scatter(idx in range(length(sraIDs))) {
    call singlesample.Ss2SingleSample as single_run {
       
    }
    call Star {
      input:
        input_fastq_read1 = sra_dir+'/'+sraIDs[idx]+"_1.fastq.gz",
        input_fastq_read2 = sra_dir+'/'+sraIDs[idx]+"_2.fastq.gz",
        gtf = gtf,
        star_genome = star_genome,
        sample_tag = sraIDs[idx],
        pu_tag = sraIDs[idx],
        lib_tag = sraIDs[idx],
        id_tag = sraIDs[idx]
    }
   call RsemExpression {
      input:
        trans_aligned_bam = Star.output_bam_trans,
        rsem_genome = rsem_genome,
        rsem_out = sraIDs[idx]
    }
    call FeatureCountsUniqueMapping {
      input:
        aligned_bam = Star.output_bam,
        gtf = gtf,
        fc_out = sraIDs[idx]
    }
    call FeatureCountsMultiMapping {
      input:
        aligned_bam=Star.output_bam,
        gtf = gtf,
        fc_out = sraIDs[idx]
    }
    call CollectRnaSeqMetrics {
      input:
        aligned_bam = Star.output_bam,
        ref_genome_fasta = ref_fasta,
        rrna_interval = rrna_interval,
        output_filename = sraIDs[idx],
        ref_flat= ref_flat
    }
    call CollectAlignmentSummaryMetrics {
      input:
        aligned_bam = Star.output_bam,
        ref_genome_fasta = ref_fasta,
        output_filename = sraIDs[idx]
    }
    call CollectDuplicationMetrics {
      input:
        aligned_bam = Star.output_bam,
        output_filename = sraIDs[idx]
    }

    call CollectInsertMetrics {
      input:
        aligned_bam = Star.output_bam,
        output_filename = sraIDs[idx]
      }
  }

  call GatherMetricsBySample {
    input:
      rna_metrics_fn = CollectRnaSeqMetrics.rna_metrics,
      aln_metrics_fn = CollectAlignmentSummaryMetrics.alignment_metrics,
      insert_metrics_fn = CollectInsertMetrics.insert_metrics,
      dup_metrics_fn =CollectDuplicationMetrics.dedup_metrics
    }
    
}
