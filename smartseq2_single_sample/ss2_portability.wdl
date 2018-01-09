import "ss2_single_sample.wdl" as target_ss2_wdl
import "ss2_checker.wdl" as ss2_checker_wdl

workflow SS2PortabilityWorkflow {
  
  # Inputs to the target workflow
  File gtf_file
  File genome_ref_fasta
  File rrna_intervals
  File gene_ref_flat
  File hisat2_ref_index
  File hisat2_ref_trans_index
  File rsem_ref_index
  File hisat2_ref_name
  File hisat2_ref_trans_name
  String stranded
  String sample_name
  String output_name
  File fastq1
  File fastq2
  
  # Test inputs
  String expected_rna_metrics_hash

  call target_ss2_wdl.SmartSeq2SingleCell as ss2_target {
    input:
      gtf_file=gtf_file,
      genome_ref_fasta=genome_ref_fasta,
      rrna_intervals=rrna_intervals,
      gene_ref_flat=gene_ref_flat,
      hisat2_ref_index=hisat2_ref_index,
      hisat2_ref_trans_name=hisat2_ref_trans_name,
      hisat2_ref_trans_index=hisat2_ref_trans_index,
      rsem_ref_index=rsem_ref_index,
      hisat2_ref_name=hisat2_ref_name,
      stranded=stranded,
      sample_name=sample_name,
      output_name=output_name,
      fastq1=fastq1,
      fastq2=fastq2
  }

  call ss2_checker_wdl.SmartSeq2Checker as ss2_checker {
    input:
      rna_metrics=ss2_target.rna_metrics,
      expected_rna_metrics_hash=expected_rna_metrics_hash
  }
}
