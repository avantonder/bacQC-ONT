/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap         } from 'plugin/nf-validation'
include { paramsSummaryMultiqc     } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText   } from '../subworkflows/local/utils_bacqcont_pipeline'
include { validateInputSamplesheet } from '../subworkflows/local/utils_bacqcont_pipeline'
include { validateParameters; paramsHelp; paramsSummaryLog; fromSamplesheet } from 'plugin/nf-validation'

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config, params.kraken2db, params.kronadb,
                           params.multiqc_logo, params.multiqc_methods_description ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if ( params.input ) {
    ch_input = file(params.input, checkIfExists: true)
} else {
    error("Input samplesheet not specified")
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

include { CAT_FASTQ as MERGE_RUNS } from '../modules/local/cat/fastq/main'
include { FASTQSCANPARSE          } from '../modules/local/fastqscanparse'
include { KRAKENPARSE             } from '../modules/local/krakenparse'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                        } from '../modules/nf-core/fastqc/main'
include { FASTQSCAN                     } from '../modules/nf-core/fastqscan/main'
include { PYCOQC                        } from '../modules/nf-core/pycoqc/main'
include { NANOPLOT                      } from '../modules/nf-core/nanoplot/main'
include { KRAKEN2_KRAKEN2               } from '../modules/nf-core/kraken2/kraken2/main'
include { BRACKEN_BRACKEN               } from '../modules/nf-core/bracken/bracken/main'
include { KRONA_KTIMPORTTAXONOMY        } from '../modules/nf-core/krona/ktimporttaxonomy/main'
include { MULTIQC                       } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BACQCONT {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:
    
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
      
    // Validate input file and create channel for FASTQ data
    ch_input = samplesheet
        .map { meta, fastq -> 
        
        // Define single_end
        //meta.single_end = ( fastq )
        
        return [ meta, fastq ]
        }
    
    if ( params.perform_runmerging ) {
    
        ch_reads_for_cat = ch_input
            .groupTuple()      
            .map { meta, fastq -> [ meta, fastq.flatten() ]}
            .branch { meta, fastq -> 
            // we can't concatenate files if there is not a second run, we branch
            // here to separate them out, and mix back in after for efficiency
                cat: ( fastq.size() > 1 )
                skip: true
            }

        ch_reads_runmerged = MERGE_RUNS ( ch_reads_for_cat.cat ).reads
                .mix( ch_reads_for_cat.skip )
                .map {
                    meta, fastq ->
                    [ meta, [ fastq ].flatten() ]
                }

            ch_versions = ch_versions.mix(MERGE_RUNS.out.versions)

    } else {
        ch_reads_runmerged = ch_input
    }
    
    /*
        MODULE: Run FastQC
    */
    FASTQC (
        ch_reads_runmerged
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // MODULE: Run fastq-scan
    //
    FASTQSCAN (
        ch_reads_runmerged,
        params.genome_size
    )
    ch_fastqscan_fastqscanparse = FASTQSCAN.out.json
    ch_versions                 = ch_versions.mix(FASTQSCAN.out.versions)

    //
    // MODULE: Run fastqscanparse
    //
    FASTQSCANPARSE (
        ch_fastqscan_fastqscanparse.collect{it[1]}.ifEmpty([])
    )
    ch_versions = ch_versions.mix(FASTQSCANPARSE.out.versions)

    //
    // MODULE: Run nanoplot
    //
    NANOPLOT (
        ch_reads_runmerged
    )
    ch_versions = ch_versions.mix(NANOPLOT.out.versions)

    //
    // MODULE: Run pycoQC
    //
    ch_summary_file = Channel.empty()
    if (!params.skip_pycoqc) {
        ch_summary_file = params.summary_file

        PYCOQC (
            ch_summary_file
        )
        ch_versions = ch_versions.mix(PYCOQC.out.versions)
    }

    //
    // MODULE: Run kraken2
    //  
    ch_kraken2_multiqc = Channel.empty()
    ch_kraken2db       = Channel.empty()
    ch_kronadb         = Channel.empty()
    if (!params.skip_kraken2) {
        ch_kraken2db = file(params.kraken2db)
        ch_kronadb   = file(params.kronadb)
        
        KRAKEN2_KRAKEN2 (
                ch_filtered_reads,
                ch_kraken2db,
                params.save_output_fastqs,
                params.save_reads_assignment
            )
        ch_kraken2_bracken             = KRAKEN2_KRAKEN2.out.report
        ch_kraken2_krakenparse         = KRAKEN2_KRAKEN2.out.report
        ch_versions                    = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions.first().ifEmpty(null))
        //
        // MODULE: Run bracken
        //
        BRACKEN_BRACKEN (
                ch_kraken2_bracken,
                ch_kraken2db
            )
        ch_bracken_krakenparse = BRACKEN_BRACKEN.out.reports
        ch_bracken_krona       = BRACKEN_BRACKEN.out.reports
        ch_versions            = ch_versions.mix(BRACKEN_BRACKEN.out.versions)

        //
        // MODULE: Run krakenparse
        //
        KRAKENPARSE (
                ch_kraken2_krakenparse.collect{it[1]}.ifEmpty([]),
                ch_bracken_krakenparse.collect{it[1]}.ifEmpty([])
            )
        ch_versions = ch_versions.mix(KRAKENPARSE.out.versions)

        //
        // MODULE: Run krona
        //
        KRONA_KTIMPORTTAXONOMY (
                ch_bracken_krona,
                ch_kronadb
            )
        ch_versions = ch_versions.mix(KRONA_KTIMPORTTAXONOMY.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.fromPath("${workflow.projectDir}/docs/images/bacqcont_logo.png", checkIfExists: true)

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    
    if (!params.skip_pycoqc){
        ch_multiqc_files = ch_multiqc_files.mix(PYCOQC.out.json.collect{it[1]}.ifEmpty([]))
    }
    if (!params.skip_kraken2) {
        ch_multiqc_files = ch_multiqc_files.mix( KRAKEN2_KRAKEN2.out.report.collect{it[1]}.ifEmpty([]) )
        ch_multiqc_files = ch_multiqc_files.mix( BRACKEN_BRACKEN.out.txt.collect{it[1]}.ifEmpty([]) )
    }

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
