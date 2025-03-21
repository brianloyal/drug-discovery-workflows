#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Boltz1 {
    take:
    input_path
    boltz1_parameters

    main:

    input_channel = Channel.fromPath(input_path)
    boltz1_parameters = Channel.fromPath(boltz1_parameters)

    input_channel.view()

    Boltz1Task(
        input_channel,
        boltz1_parameters
        )

    emit:
    Boltz1Task.out
}

process Boltz1Task {
    label 'boltz1'
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
    path input_path
    path boltz1_parameters

    output:
    path "output/*", emit: output

    script:
    """
    set -euxo pipefail
    mkdir output
    /opt/venv/bin/boltz predict \
    --cache $boltz1_parameters \
    --out_dir output \
    $input_path
      
    """
}

workflow {
    Boltz1(
        params.input_path,
        params.boltz1_parameters
    )
}
