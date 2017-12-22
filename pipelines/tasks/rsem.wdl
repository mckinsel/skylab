## RSEM will estimate gene/isoform quantification
## --bam: input is bam file
## -p 4: run on multiple threads
## --time: report running time
## --seed: report deterministic results
## potientially, we can run RSEM with --calc-pme --single-cell-prior
## 
task RsemExpression {
  File trans_aligned_bam
  File rsem_genome
  String rsem_out
  Float disk_size
  command {
    set -e
  
    tar -xvf ${rsem_genome}
    rsem-calculate-expression \
      --bam \
      --paired-end \
       -p 4 \
      --time --seed 555 \
      ${trans_aligned_bam} \
      rsem/rsem_trans_index  \
      "${rsem_out}" 
  }
  runtime {
    docker: "quay.io/humancellatlas/secondary-analysis-rsem:1.3.0"
    memory: "3.75 GB"
    disks: "local-disk " + sub(disk_size, "\\..*", "") + " HDD"
    cpu: "4"
  }
  output {
    File rsem_gene = "${rsem_out}.genes.results"
    File rsem_isoform = "${rsem_out}.isoforms.results"
    File rsem_time = "${rsem_out}.time"
    File rsem_cnt = "${rsem_out}.stat/${rsem_out}.cnt"
    File rsem_model = "${rsem_out}.stat/${rsem_out}.model"
    File rsem_theta = "${rsem_out}.stat/${rsem_out}.theta"
  }
}

