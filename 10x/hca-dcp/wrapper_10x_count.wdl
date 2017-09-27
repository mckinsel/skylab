import "count.wdl" as countwdl
import "submit.wdl" as submit_wdl

task GetInputs {
  String bundle_uuid
  String bundle_version
  String dss_url
  Int retry_seconds
  Int timeout_seconds

  command <<<
    python <<CODE
    import json
    import requests
    import subprocess
    import time

    # Get bundle manifest
    uuid = '${bundle_uuid}'
    version = '${bundle_version}'
    print('Getting bundle manifest for id {0}, version {1}'.format(uuid, version))

    url = "${dss_url}/bundles/" + uuid + "?version=" + version + "&replica=gcp&directurls=true"
    start = time.time()
    current = start
    while current - start < ${timeout_seconds}:
        print('GET {0}'.format(url))
        response = requests.get(url)
        print('{0}'.format(response.status_code))
        print('{0}'.format(response.text))
        if 200 <= response.status_code <= 299:
            break
        time.sleep(${retry_seconds})
        current = time.time()
    manifest = response.json()

    bundle = manifest['bundle']
    uuid_to_url = {}
    name_to_meta = {}
    for f in bundle['files']:
        uuid_to_url[f['uuid']] = f['url']
        name_to_meta[f['name']] = f

    print('Downloading assay.json')
    assay_json_uuid = name_to_meta['assay.json']['uuid']
    url = "${dss_url}/files/" + assay_json_uuid + "?replica=gcp"
    print('GET {0}'.format(url))
    response = requests.get(url)
    print('{0}'.format(response.status_code))
    print('{0}'.format(response.text))
    assay_json = response.json()

    # Parse inputs from assay_json and write to inputs.tsv file
    sample_id = assay_json['sample_id']
    lanes = assay_json['seq']['lanes']
    r1 = [name_to_meta[lane['r1']]['url'] for lane in lanes]
    r2 = [name_to_meta[lane['r2']]['url'] for lane in lanes]
    i1 = [name_to_meta[lane['i1']]['url'] for lane in lanes]

    with open('r1.tsv', 'w') as f:
        for r in r1:
            f.write('{0}\n'.format(r))
    with open('r2.tsv', 'w') as f:
        for r in r2:
            f.write('{0}\n'.format(r))
    with open('i1.tsv', 'w') as f:
        for i in i1:
            f.write('{0}\n'.format(i))
    print('Creating input map')
    with open('inputs.tsv', 'w') as f:
        f.write('sample_id\n')
        f.write('{0}\n'.format(sample_id))
    print('Wrote input map')
    CODE
  >>>
  runtime {
    docker: "humancellatlas/secondary-analysis-python"
  }
  output {
    Array[File] r1 = read_lines("r1.tsv")
    Array[File] r2 = read_lines("r2.tsv")
    Array[File] i1 = read_lines("i1.tsv")
    Object inputs = read_object("inputs.tsv")
  }
}

workflow Wrapper10xCount {
  String bundle_uuid
  String bundle_version

  File sample_def
  Int reads_per_file
  Float subsample_rate
  Array[Map[String, String]] primers
  String align
  File reference_path
  Int umi_min_qual_threshold

  # Submission
  File format_map
  String dss_url
  String submit_url
  String reference_bundle
  String run_type
  String schema_version
  String method
  Int retry_seconds
  Int timeout_seconds

  call GetInputs as prep {
    input:
      bundle_uuid = bundle_uuid,
      bundle_version = bundle_version,
      dss_url = dss_url,
      retry_seconds = retry_seconds,
      timeout_seconds = timeout_seconds
  }

  call countwdl.count as analysis {
    input:
      sample_def = sample_def,
      r1 = prep.r1,
      r2 = prep.r2,
      i1 = prep.i1,
      sample_id = prep.inputs.sample_id,
      reads_per_file = reads_per_file,
      subsample_rate = subsample_rate,
      primers = primers,
      align = align,
      reference_path = reference_path,
      umi_min_qual_threshold = umi_min_qual_threshold
  }

  call submit_wdl.submit {
    input:
      inputs = [
        {
          'name': 'sample_def',
          'value': sample_def,
        },
        {
          'name': 'r1',
          'value': prep.inputs.r1,
        },
        {
          'name': 'r2',
          'value': prep.inputs.r2,
        },
        {
          'name': 'i1',
          'value': prep.inputs.i1,
        },
        {
          'name': 'sample_id',
          'value': prep.inputs.sample_id,
        },
        {
          'name': 'reads_per_file',
          'value': reads_per_file,
        },
        {
          'name': 'subsample_rate',
          'value': subsample_rate,
        },
        {
          'name': 'primers',
          'value': primers,
        },
        {
          'name': 'align',
          'value': align,
        },
        {
          'name': 'reference_path',
          'value': reference_path,
        },
        {
          'name': 'umi_min_qual_threshold',
          'value': umi_min_qual_threshold,
        }
      ],
      outputs = [
        analysis.attach_bcs_and_umis_summary,
        analysis.filter_barcodes.summary,
        analysis.count_genes_join.reporter_summary,
        analysis.extract_reads_join.summary,
        analysis.mark_duplicates_join.summary,
        analysis.count_genes_join.matrices_mex,
        analysis.count_genes_join.matrices_h5,
        analysis.filter_barcodes.filtered_matrices_mex,
        analysis.filter_barcodes.filtered_matrices_h5,
        analysis.sort_by_bc_join.default
      ],
      format_map = format_map,
      submit_url = submit_url,
      input_bundle_uuid = bundle_uuid,
      reference_bundle = reference_bundle,
      run_type = run_type,
      schema_version = schema_version,
      method = method,
      retry_seconds = retry_seconds,
      timeout_seconds = timeout_seconds
  }
}
