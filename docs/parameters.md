# avantonder/bacQC-ONT pipeline parameters                                                                                         
                                                                                                                                   
**bacQC-ONT** is a bioinformatics pipeline for the assessment of Oxford Nanopore sequence data. It assesses read quality with `fastQC`, `nanoplot` and `pycoQC`, and species composition with `Kraken2` and `Bracken`.                                                                                                
                                                                                                                                   
## Input/output options                                                                                                            
                                                                                                                                   
Define where the pipeline should find input data and save output data.                                                             
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `input` | Path to comma-separated file containing information about the samples in the experiment.                               <details><summary>Help</summary><small>You will need to create a design file with information about the samples in your experiment before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 3 columns, and a header row. See [usage docs](https://nf-co.re/bacqcont/usage#samplesheet-input).</small></details> | `string` |  | True |  |        
| `outdir` | The output directory where the results will be saved. You have to use absolute paths to storage on Cloud              infrastructure. | `string` |  | True |  |             
| `summary_file` | ONT sequencing summary statistics file (sequencing_summary.txt) | `string` |  |  |  |                           
| `email` | Email address for completion summary. <details><summary>Help</summary><small>Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to specify this on the command line for every run.</small></details> |`string` |  |  |                                                    
| `multiqc_title` | MultiQC report title. Printed as page header, used for filename if not otherwise specified. | `string` |  |  |                                                            
| `perform_runmerging` | Turn on run merging | `boolean` | True |  |  |                                                            
| `save_runmerged_reads` | Save reads from samples that went through the run-merging step | `boolean` | True |  |  |               
                                                                                                                                   
## fastq-scan options                                                                                                              
                                                                                                                                   
fastq-scan related options required for the workflow                                                                               
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `genome_size` | Specify a genome size to be used by fastq-scan to calculate coverage e.g. 4300000 | `integer` |  |  |  |         
                                                                                                                                   
## PycoQC options                                                                                                                  
pycoQC related options required for the workflow       
                                                                                                                                   
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `skip_pycoqc` | Skip pycoQC (if no sequencing_summary.txt file is available) | `boolean` | True |  |  |                          
                                                                                                                                   
## Kraken options                                                                                                                  
                                                                                                                                   
Kraken 2 and Bracken related files and options required for the workflow                                                           
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `skip_kraken2` | Skip species composition check | `boolean` |  |  |  |                                                           
| `kraken2db` | Path to Kraken 2 database | `string` |  |  |  |                                                                    
| `save_output_fastqs` | Turn on saving of Kraken2 per-read taxonomic assignment file | `boolean` |  |  |  |                       
| `save_reads_assignment` |  | `boolean` | True |  |  |                                                                            
                                                                                                                                   
## Krona options                                                                                                                   
 Krona related options required for the workflow                                                                                                                                  
                                                                                                                                   
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `kronadb` | Path to Krona taxonomy.tab file | `string` |  |  |  |                                                                
                                                                                                                                   
## Institutional config options                                                                                                    
                                                                                                                                   
Parameters used to describe centralised config profiles. These should not be edited.                                               
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `custom_config_version` | Git commit id for Institutional configs. | `string` | master |  | True |                               
| `custom_config_base` | Base directory for Institutional configs. <details><summary>Help</summary><small>If you're running offline, Nextflow will not be able to fetch the institutional config files from the internet. If you don't need them, then this is not a problem. If you do need them, you should download the files from the repo and tell Nextflow where to find them with this parameter.</small></details>| `string` | https://raw.githubusercontent.com/nf-core/configs/master |  | True |                      
| `config_profile_name` | Institutional config name. | `string` |  |  | True |                                                     
| `config_profile_description` | Institutional config description. | `string` |  |  | True |                                       
| `config_profile_contact` | Institutional config contact information. | `string` |  |  | True |                                   
| `config_profile_url` | Institutional config URL link. | `string` |  |  | True |                                                  
                                                                                                                                   
## Max job request options                                                                                                         
                                                                                                                                   
Set the top limit for requested resources for any single job.                                                                      
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `max_cpus` | Maximum number of CPUs that can be requested for any single job. <details><summary>Help</summary><small>Use to set an upper-limit for the CPU requirement for each process. Should be an integer e.g `--max_cpus 1`</small></details>| `integer` | 16 |    True |                                                                                                                        
| `max_memory` | Maximum amount of memory that can be requested for any single job. <details><summary>Help</summary><small>Use to set an upper-limit for the memory requirement for each process. Should be a string in the format integer-unit e.g. `--max_memory   
'8.GB'`</small></details>| `string` | 128.GB |  | True |                                                                           
| `max_time` | Maximum amount of time that can be requested for any single job. <details><summary>Help</summary><small>Use to set  an upper-limit for the time requirement for each process. Should be a string in the format integer-unit e.g. `--max_time           
'2.h'`</small></details>| `string` | 240.h |  | True |                                                                             
                                                                                                                                   
## Generic options                                                                                                                 
                                                                                                                                   
Less common options for the pipeline, typically set in a config file.                                                              
                                                                                                                                   
| Parameter | Description | Type | Default | Required | Hidden |                                                                   
|-----------|-----------|-----------|-----------|-----------|-----------|                                                          
| `help` | Display help text. | `boolean` |  |  | True |                                                                           
| `version` | Display version and exit. | `boolean` |  |  | True |                                                                 
| `publish_dir_mode` | Method used to save pipeline results to output directory. <details><summary>Help</summary><small>The Nextflow `publishDir` option specifies which intermediate files should be saved to the output directory. This option tells the pipeline what method should be used to move these files. See [Nextflow docs](https://www.nextflow.io/docs/latest/process.html#publishdir) for details.</small></details>| `string` | copy |  | True |     
| `email_on_fail` | Email address for completion summary, only when pipeline fails. <details><summary>Help</summary><small>An email address to send a summary email to when the pipeline is completed - ONLY sent if the pipeline does not exit successfully.</small></details>| `string` |  |  | True |                                                                           
| `plaintext_email` | Send plain-text email instead of HTML. | `boolean` |  |  | True |                                            
| `max_multiqc_email_size` | File size limit when attaching MultiQC reports to summary emails. | `string` | 25.MB |  | True |      
| `monochrome_logs` | Do not use coloured log outputs. | `boolean` |  |  | True |                                                  
| `hook_url` | Incoming hook URL for messaging service <details><summary>Help</summary><small>Incoming hook URL for messaging service. Currently, MS Teams and Slack are supported.</small></details>| `string` |  |  | True |                                   
| `multiqc_config` | Custom config file to supply to MultiQC. | `string` |  |  | True |                                            
| `multiqc_logo` | Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file | `string` |  |  |True |                                                                                                                             
| `multiqc_methods_description` | Custom MultiQC yaml file containing HTML including a methods description. | `string` |  |  |  |  
| `validate_params` | Boolean whether to validate parameters against the schema at runtime | `boolean` | True |  | True |          
| `validationShowHiddenParams` | Show all params when using `--help` <details><summary>Help</summary><small>By default, parameters set as _hidden_ in the schema are not shown on the command line when a user runs with `--help`. Specifying this option will tell the pipeline to show all parameters.</small></details>| `boolean` |  |  | True |                                                   
| `validationFailUnrecognisedParams` | Validation of parameters fails when an unrecognised parameter is found.    <details><summary>Help</summary><small>By default, when an unrecognised parameter is found, it returns a warning.</small></details>| `boolean` |  |  | True |                                                                               
| `validationLenientMode` | Validation of parameters in lenient mode. <details><summary>Help</summary><small>Allows string values that are parseable as numbers or booleans. For further information see [JSONSchema                                                 docs](https://github.com/everit-org/json-schema#lenient-mode).</small></details>| `boolean` |  |  | True |                         
| `pipelines_testdata_base_path` |  | `string` | https://raw.githubusercontent.com/nf-core/test-datasets/ |  |  |                  
| `trace_report_suffix` |  | `string` | 2025-03-04_14-01-29 |  |  |