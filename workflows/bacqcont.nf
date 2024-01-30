/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PRINT PARAMS SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-validation'

def logo = NfcoreTemplate.logo(workflow, params.monochrome_logs)
def citation = '\n' + WorkflowMain.citation(workflow) + '\n'
def summary_params = paramsSummaryMap(workflow)

// Print parameter summary log to screen
log.info logo + paramsSummaryLog(workflow) + citation

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

WorkflowBacqcont.initialise(params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK    } from '../subworkflows/local/input_check'
include { FASTQSCANPARSE } from '../modules/local/fastqscanparse'
include { KRAKENPARSE    } from '../modules/local/krakenparse'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { ARTIC_GUPPYPLEX               } from '../modules/nf-core/artic/guppyplex/main'
include { FASTQC                        } from '../modules/nf-core/fastqc/main'
include { FASTQSCAN                     } from '../modules/nf-core/fastqscan/main'
include { PYCOQC                        } from '../modules/nf-core/pycoqc/main'
include { NANOPLOT                      } from '../modules/nf-core/nanoplot/main'
include { KRAKEN2_KRAKEN2               } from '../modules/nf-core/kraken2/kraken2/main'
include { BRACKEN_BRACKEN               } from '../modules/nf-core/bracken/bracken/main'
include { MULTIQC                       } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow BACQCONT {

    ch_versions = Channel.empty()

    // Prepare input from barcode directory specified with --fastq_dir flag

    barcode_dirs = file("${params.fastq_dir}/barcode*", type: 'dir' , maxdepth: 1)

    Channel
            .fromPath( barcode_dirs )
            .filter( ~/.*barcode[0-9]{1,4}$/ )
            .map { dir ->
                def count = 0
                for (x in dir.listFiles()) {
                    if (x.isFile() && x.toString().contains('.fastq')) {
                        count += x.countFastq()
                    }
                }
                return [ dir.baseName , dir, count ]
            }
            .set { ch_fastq_dirs }
    
    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        file(params.input)
    )
    .sample_info
    .join(ch_fastq_dirs, remainder: true)
    .map { barcode, sample, dir, count -> [ [ id: sample, barcode:barcode ], dir ] }
    .set { ch_fastq_dirs }
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)
    
    //
    // MODULE: Run Artic Guppyplex
    //
    ARTIC_GUPPYPLEX (
        ch_fastq_dirs
    )
    ch_versions = ch_versions.mix(ARTIC_GUPPYPLEX.out.versions.first())

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ARTIC_GUPPYPLEX.out.fastq
    )
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // MODULE: Run fastq-scan
    //
    FASTQSCAN (
        ARTIC_GUPPYPLEX.out.fastq,
        params.genome_size
    )
    ch_fastqscan_fastqscanparse = FASTQSCAN.out.json
    ch_versions                 = ch_versions.mix(FASTQSCAN.out.versions.first())

    //
    // MODULE: Run fastqscanparse
    //
    FASTQSCANPARSE (
        ch_fastqscan_fastqscanparse.collect{it[1]}.ifEmpty([])
    )
    ch_versions = ch_versions.mix(FASTQSCANPARSE.out.versions.first())

    //
    // MODULE: Run nanoplot
    //
    NANOPLOT (
        ARTIC_GUPPYPLEX.out.fastq
    )
    ch_versions = ch_versions.mix(NANOPLOT.out.versions.first())

    //
    // MODULE: Run pycoQC
    //
    ch_summary_file = Channel.empty()
    if (!params.skip_pycoqc) {
        ch_summary_file = params.summary_file

        PYCOQC (
            ch_summary_file
        )
        ch_versions = ch_versions.mix(PYCOQC.out.versions.first())
    }

    //
    // MODULE: Run kraken2
    //  
    ch_kraken2db = Channel.empty()
    if (!params.skip_kraken2) {
        ch_kraken2db = file(params.kraken2db)
        
        KRAKEN2_KRAKEN2 (
                ARTIC_GUPPYPLEX.out.fastq,
                ch_kraken2db
            )
        ch_kraken2_bracken     = KRAKEN2_KRAKEN2.out.txt
        ch_kraken2_krakenparse = KRAKEN2_KRAKEN2.out.txt
        ch_versions            = ch_versions.mix(KRAKEN2_KRAKEN2.out.versions.first().ifEmpty(null))
        //
        // MODULE: Run bracken
        //
        BRACKEN_BRACKEN (
                ch_kraken2_bracken,
                ch_kraken2db
            )
        ch_bracken_krakenparse = BRACKEN_BRACKEN.out.reports
        ch_versions            = ch_versions.mix(BRACKEN_BRACKEN.out.versions.first())

        //
        // MODULE: Run krakenparse
        //
        KRAKENPARSE (
                ch_kraken2_krakenparse.collect{it[1]}.ifEmpty([]),
                ch_bracken_krakenparse.collect{it[1]}.ifEmpty([])
            )
        ch_versions = ch_versions.mix(KRAKENPARSE.out.versions.first())
    }

    //
    // MODULE: Collate software versions
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )
    
    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowBacqcont.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowBacqcont.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description, params)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    
    if (!params.skip_pycoqc){
        ch_multiqc_files = ch_multiqc_files.mix(PYCOQC.out.json.collect{it[1]}.ifEmpty([]))
    }
    if (!params.skip_kraken2){
        ch_multiqc_files = ch_multiqc_files.mix(KRAKEN2_KRAKEN2.out.txt.collect{it[1]}.ifEmpty([]))
    }

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
