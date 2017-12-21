import "hisat2_QC_pipeline.wdl" as run_hisat2
import "hisat2_rsem_pipeline.wdl" as run_hisat2_rsem
## main pipeline:
## QC pipeline: HISAT2+Picard on genome alignments
## quantification pipeline: HISAT2+RSEM on transcriptome alignments

workflow run_pipeline {

  # load annotation
  File gtffile
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
  # array of string represents featuretypes
  # samples
  String stranded
  String sample_name
  String output_name
  File fastq1
  File fastq2
  
  call run_hisat2.RunHisat2Pipeline {
    input:
      fastq_read1 = fastq1,
      fastq_read2 = fastq2, 
      gtf = gtffile,
      stranded = stranded,
      ref_fasta = genome_ref_fasta,
      rrna_interval = rrna_intervals,
      ref_flat = gene_ref_flat,
      hisat2_ref = hisat2_ref_index,
      hisat2_ref_name = hisat2_ref_name,
      sample_name = sample_name,
      output_prefix = output_name
  }
  call run_hisat2_rsem.RunHisat2RsemPipeline {
    input:
      fastq_read1 = fastq1, 
      fastq_read2 = fastq2, 
      hisat2_ref_trans = hisat2_ref_trans_index,
      hisat2_ref_trans_name = hisat2_ref_trans_name,
      rsem_genome = rsem_ref_index,
      output_prefix = output_name,
      sample_name = sample_name
  }
}
