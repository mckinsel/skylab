import "hisat2.wdl" as hisat2
import "rsem.wdl" as rsem
## quantification pipeline
## hisat2 as aligner to align reads to transcriptome
## rsem will estimate the expression levels for both gene/isoform
## output: in genes.results and isoform.results. 
## in current pipeline, RSEM will only output MLE results. 
## 
workflow RunHisat2RsemPipeline {
  File fastq_read1
  File fastq_read2
  File hisat2_ref_trans
  File rsem_genome
  String output_prefix
  String hisat2_ref_trans_name
  String sample_name
  ##variable to estimate disk size
  ## variables to estimate disk size
  Float hisat2_ref_size = size(hisat2_ref_trans,"GB")
  Float fastq_size = size(fastq_read1,"GB") +size(fastq_read2,"GB")
  Float rsem_ref_size = size(rsem_genome,"GB")
  Float md_disk_multiplier = 3.25
  Int? increase_disk_size
  Int additional_disk = select_first([increase_disk_size, 10])
  
  call hisat2.HISAT2rsem as Hisat2Trans {
    input:
      hisat2_ref = hisat2_ref_trans,
      fq1 = fastq_read1,
      fq2 = fastq_read2,
      ref_name = hisat2_ref_trans_name,
      sample_name = sample_name,
      output_name = output_prefix,
      disk_size = fastq_size*md_disk_multiplier+hisat2_ref_size+additional_disk
      
    }
  Float bam_size = size(Hisat2Trans.output_bam,"GB")
  call rsem.RsemExpression as Rsem {
    input:
      trans_aligned_bam = Hisat2Trans.output_bam,
      rsem_genome = rsem_genome,
      rsem_out = output_prefix,
      disk_size = fastq_size*md_disk_multiplier+rsem_ref_size+additional_disk
    }
  output {
    File aligned_trans_bam = Hisat2Trans.output_bam
    File metfile = Hisat2Trans.metfile
    File logfile = Hisat2Trans.logfile
    File rsem_gene_results = Rsem.rsem_gene
    File rsem_isoform_results = Rsem.rsem_isoform
    File rsem_time_log = Rsem.rsem_time
    File rsem_cnt_log = Rsem.rsem_cnt
    File rsem_model_log = Rsem.rsem_model
    File rsem_theta_log = Rsem.rsem_theta
  }
}
