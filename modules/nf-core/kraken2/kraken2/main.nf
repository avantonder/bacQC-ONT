process KRAKEN2_KRAKEN2 {
    tag "$meta.id"
    label 'process_high'

    conda "bioconda::kraken2=2.1.2 conda-forge::pigz=2.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:87fc08d11968d081f3e8a37131c1f1f6715b6542-0' :
        'quay.io/biocontainers/mulled-v2-5799ab18b5fc681e75923b2450abaa969907ec98:87fc08d11968d081f3e8a37131c1f1f6715b6542-0' }"

    input:
    tuple val(meta), path(reads)
    path db

    output:
    tuple val(meta), path('*classified*')  , emit: classified
    tuple val(meta), path('*unclassified*'), emit: unclassified
    tuple val(meta), path('*report.txt')   , emit: txt
    tuple val(meta), path('*.out')         , emit: output
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    kraken2 \\
        --db $db \\
        --threads $task.cpus \\
        --unclassified-out ${prefix}.unclassified.fastq \\
        --classified-out ${prefix}.classified.fastq \\
        --report ${prefix}.kraken2.report.txt \\
        --output ${prefix}.kraken2.out \\
        --gzip-compressed \\
        $args \\
        $reads

    pigz -p $task.cpus *.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        kraken2: \$(echo \$(kraken2 --version 2>&1) | sed 's/^.*Kraken version //; s/ .*\$//')
        pigz: \$( pigz --version 2>&1 | sed 's/pigz //g' )
    END_VERSIONS
    """
}