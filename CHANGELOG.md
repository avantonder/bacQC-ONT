# avantonder/bacQC-ONT: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.0.0 - [04/03/25]

- Significant recoding of pipeline to bring it more in line with current nf-core template.
- Add Krona to produce graphical outputs of Bracken results. Path to Krona Taxonomy file will have to be specified with `--kronadb`.
- Update FastQC from version 0.11.9 to version 0.12.1.
- Update nanoplot from version 1.41.0 to version 1.41.6
- Update Kraken 2 from version 2.1.2 to version 2.1.3.
- Update Bracken from version 2.7 to version 2.9.
- Update MultiQC from version 1.14 to version 1.25.1. Report now includes Bracken outputs and Kraken 2 outputs.

## v1.1 - [30/01/24]

- Remove `--brackendb` parameter as redundant. Bracken will now use the database location specified with `--krakendb`.
- Documentation updated.

## v1.0.0 - [22/09/23]

Initial release of avantonder/bacQC-ONT, created with the [nf-core](https://nf-co.re/) template.
