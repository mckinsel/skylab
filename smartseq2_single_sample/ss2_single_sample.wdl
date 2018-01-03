import "hisat2_QC_pipeline.wdl" as run_hisat2
import "hisat2_rsem_pipeline.wdl" as run_hisat2_rsem
## main pipeline:
## QC track: HISAT2+Picard
## this track will produce aligned bam file and a set of QC metrics
## rsem quantification track: HISAT2+RSEM
## this track involves hisat2 transcriptome alignment and RSEM gene expression estimation.

workflow SmartSeq2SingleCell {

  # load annotation
  File gtf_file
  File genome_ref_fasta
  File rrna_intervals
  File gene_ref_flat
  #load index
  File hisat2_ref_index
  File hisat2_ref_trans_index
  File rsem_ref_index
  # ref index name
  File hisat2_ref_name
  File hisat2_ref_trans_name
  # samples
  String stranded
  String sample_name
  String output_name
  File fastq1
  File fastq2

  call run_hisat2.RunHisat2Pipeline as data {
    input:
      fastq_read1 = fastq1,
      fastq_read2 = fastq2, 
      gtf = gtf_file,
      stranded = stranded,
      ref_fasta = genome_ref_fasta,
      rrna_interval = rrna_intervals,
      ref_flat = gene_ref_flat,
      hisat2_ref = hisat2_ref_index,
      hisat2_ref_name = hisat2_ref_name,
      sample_name = sample_name,
      output_prefix = output_name
      
  }

  call run_hisat2_rsem.RunHisat2RsemPipeline as qc {
    input:
      fastq_read1 = fastq1, 
      fastq_read2 = fastq2, 
      hisat2_ref_trans = hisat2_ref_trans_index,
      hisat2_ref_trans_name = hisat2_ref_trans_name,
      rsem_genome = rsem_ref_index,
      output_prefix = output_name,
      sample_name = sample_name
  }

  output {
    # data workflow outputs
    File aligned_trans_bam = data.output_bam
    File data_metfile = data.metfile
    File data_logfile = data.logfile
    File rsem_gene_results = data.rsem_gene
    File rsem_isoform_results = data.rsem_isoform
    File rsem_time_log = data.rsem_time
    File rsem_cnt_log = data.rsem_cnt
    File rsem_model_log = data.rsem_model
    File rsem_theta_log = data.rsem_theta
    # qc workflow outputs
    File aligned_bam = qc.output_bam
    File qc_metfile = qc.metfile
    File qc_logfile = qc.logfile
    File alignment_summary_metrics = qc.alignment_summary_metrics
    File base_call_dist_metrics = qc.base_call_dist_metrics
    File base_call_pdf = qc.base_call_pdf
    File gc_bias_detail_metrics = qc.gc_bias_detail_metrics
    File gc_bias_dist_pdf = qc.gc_bias_dist_pdf
    File gc_bias_summary_metrics = qc.gc_bias_summary_metrics
    File insert_size_hist = qc.insert_size_hist
    File insert_size_metrics = qc.insert_size_metrics
    File quality_distribution_metrics = qc.quality_distribution_metrics
    File quality_distribution_dist_pdf = qc.quality_distribution_dist_pdf
    File quality_by_cycle_metrics = qc.quality_by_cycle_metrics
    File quality_by_cycle_pdf = qc.quality_by_cycle_pdf
    File pre_adapter_details_metrics = qc.pre_adapter_details_metrics
    File bait_bias_detail_metrics = qc.bait_bias_detail_metrics
    File bait_bias_summary_metrics = qc.bait_bias_summary_metrics
    File error_summary_metrics = qc.error_summary_metrics
    File rna_metrics = qc.rna_metrics
    File rna_coverage = qc.rna_coverage_pdf
    File dedup_metrics = qc.dedup_metrics
  }
}
