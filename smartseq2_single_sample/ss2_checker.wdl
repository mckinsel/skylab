task SmartSeq2Checker {
  File rna_metrics

  String expected_rna_metrics_hash

  command <<<
    set -e
    rna_metrics_hash=$(tail -n +6 ${rna_metrics} | md5sum | awk '{print $1}')
    
    if [ "$rna_metrics_hash" != "${expected_rna_metrics_hash}" ]; then
      exit 1
    fi
  >>>

  output {}
}
