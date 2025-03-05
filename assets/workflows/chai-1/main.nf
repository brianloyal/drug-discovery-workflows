#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

workflow Chai1 {
    take:
        fasta_file
        msa_directory
        template_hits_path
        constraints_path
        pdb_snapshot_path
        chai1_parameters
        recycle_msa_subsample
        num_trunk_recycles
        num_diffn_timesteps
        num_diffn_samples
        num_trunk_samples
        seed

    main:

    // If no template hits are provided, don't import the pdb snapshot
    pdb_snapshot_path = template_hits_path != '/home/scripts/NO_TEMPLATE' ?  pdb_snapshot_path : '/home/scripts/NO_PDB'
    
    chai1_parameters = Channel.fromPath(chai1_parameters)

    Chai1Task(
        fasta_file,
        msa_directory,
        template_hits_path,
        constraints_path,
        pdb_snapshot_path,
        chai1_parameters,
        recycle_msa_subsample,
        num_trunk_recycles,
        num_diffn_timesteps,
        num_diffn_samples,
        num_trunk_samples,
        seed,
    )

    emit:
    Chai1Task.out
}

process Chai1Task {
    label 'chai1'
    debug true
    cpus 4
    memory '16 GB'
    maxRetries 1
    accelerator 1, type: 'nvidia-tesla-a10g'
    publishDir "/mnt/workflow/pubdir/${workflow.sessionId}/${task.process.replace(':', '/')}/${task.index}/${task.attempt}"

    input:
        path fasta_file
        path msa_directory
        path template_hits
        path constraints_path
        path pdb
        path chai1_parameters
        val recycle_msa_subsample
        val num_trunk_recycles
        val num_diffn_timesteps
        val num_diffn_samples
        val num_trunk_samples
        val seed

    output:
        path 'output/*'

    script:
        def run_w_msas = msa_directory.name != 'NO_MSA' ? 1 : 0
        def run_w_templates = template_hits.name != 'NO_TEMPLATE' ? 1 : 0
        def run_w_constraints = constraints_path.name != 'NO_CONSTRAINTS' ? 1 : 0
        def fold_options = ''
        fold_options = run_w_msas == 1 ? "$fold_options --msa-directory $msa_directory" : fold_options
        fold_options = run_w_templates == 1 ? "$fold_options --template-hits-path $template_hits" : fold_options
        fold_options = run_w_constraints == 1 ? "$fold_options --constraint-path $constraints_path" : fold_options
        """
        set -euxo pipefail
        mkdir output
        
        # Put parameters in the right spot
        ln -s  $chai1_parameters models_v2
        ln -s  $chai1_parameters/conformers_v1.apkl \$(pwd)
        ln -s  $chai1_parameters/facebook facebook

        export PDB_TEMPLATE_DIR=${pdb}
        export CHAI_DOWNLOADS_DIR=\$(pwd)

        ls -lahR

        # Parse colab results
        if [[ $run_w_msas -eq 1 ]]; then
          /opt/venv/bin/python /home/scripts/parse_colab_search.py $msa_directory \
          --envdb_unpaired_path $msa_directory/bfd.mgnify30.metaeuk30.smag30.a3m \
          --uniref_unpaired_path $msa_directory/uniref.a3m \
          --paired_path $msa_directory/pair.a3m
        fi

        chai-lab fold \
        ${fold_options} \
        ${fasta_file} output
        """
}

workflow {
    Chai1(
        params.fasta_file,
        params.msa_directory,
        params.template_hits_path,
        params.constraints_path,
        params.pdb_snapshot_path,
        params.chai1_parameters,
        params.recycle_msa_subsample,
        params.num_trunk_recycles,
        params.num_diffn_timesteps,
        params.num_diffn_samples,
        params.num_trunk_samples,
        params.seed
    )
}
