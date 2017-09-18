import "ss2_single_sample_wf.wdl" as singlesample

task GatherMetrics {

  Array[File]+ input_metrics_fn
  String output_filename
  
  command <<<
    i=1
    for f in ${sep=' ' input_metrics_fn};do
      sid=$(echo $f|rev| cut -d '/' -f 1 | rev |cut -d '.' -f 1)
      if [ $i == "1" ];then
        header=`cat $f|awk 'NR==7 {print $_}'`
        echo "SampleID "$header > "${output_filename}_metrics"
        i=0
      fi
      if [ ${output_filename} == "aln" ];then
        newline=`cat $f|awk 'NR==10 {print $_}'`
      else
        newline=`cat $f|awk 'NR==8 {print $_}'`
      fi
      echo $sid" "$newline >>"${output_filename}_metrics"
  done
 
 >>>
  
  output {
    File merged_metrics = "${output_filename}_metrics"
  }

  runtime {
    docker: "ubuntu:latest"
    memory: "4 GB"
    dicks: "local-disk 10 HDD"
  }
}

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
    call singlesample.Ss2RunSingleSample as single_run {  
      input:
        fastq_read1 = sra_dir+'/'+sraIDs[idx]+"_1.fastq.gz",
        fastq_read2 = sra_dir+'/'+sraIDs[idx]+"_2.fastq.gz",
        gtf = gtf,
        ref_fasta = ref_fasta,
        rrna_interval = rrna_interval,
        ref_flat = ref_flat,
        star_genome = star_genome,
        rsem_genome = rsem_genome,
        output_prefix = sraIDs[idx]
    
    }
 }

 call GatherMetrics as collect_rna {
  input:
    output_filename = 'rna',
    input_metrics_fn = single_run.rna_metrics
 }
 call GatherMetrics as collect_dup {
  input:
    output_filename = 'dedup',
    input_metrics_fn  = single_run.dedup_metrics
 }
call GatherMetrics as collect_insert {
  input:
    output_filename = 'insert',
    input_metrics_fn = single_run.insert_metrics
}
call GatherMetrics as collect_aln {
  input:
    output_filename = 'aln',
    input_metrics_fn = single_run.aln_metrics
}
 output {
   single_run.*
   collect_rna.*
   collect_dup.*
   collect_insert.*
   collect_aln.*
  }
}
