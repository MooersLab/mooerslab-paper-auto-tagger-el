![Version](https://img.shields.io/static/v1?label=mooerslab-pdf-auto-tagger-el&message=0.1&color=brightcolor)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)


# Elisp package that uses NLP to generate and add tags to PDF files of research papers

## Objective

Automate the generation and addition of tags to PDF files whose names are in a selected region in a buffer inside of Emacs.

## Main Functions:

- *mooerslab-tag-papers-in-region*: Tag all PDFs listed in a region.
- *mooerslab-extract-paper-keywords*: Test keyword extraction on a single PDF.

## Features

- Preserves existing tags (appends new ones)
- Multiple extraction methods with automatic fallback
- Detailed progress reporting
- Comprehensive summary buffer
- Support for multiple PDF text extraction tools

## Dependencies
```python
python3 --version
# poppler-utils for better PDF text extraction
brew install poppler

# PyPDF2 for fallback PDF reading
pip install PyPDF2
or better keyword extraction
pip install spacy
python -m spacy download en_core_web_sm
```

## Usage

```elisp
;; Select a region with PDF filenames (one per line)
;; Then run:
M-x mooerslab-tag-papers-in-region
;; Enter the path to the folder containing the PDFs

;; Test on a single file:
M-x mooerslab-extract-paper-keywords
```


## Update history

|Version      | Changes                                                                                                                                                                         | Date                 |
|:-----------|:------------------------------------------------------------------------------------------------------------------------------------------------------------|:--------------------|
| Version 0.1 |   Added badges, funding, and update table.  Initial commit.                                                                                        | 11/16/2025  |

## Sources of funding

- NIH: R01 CA242845
- NIH: R01 AI088011
- NIH: P30 CA225520 (PI: R. Mannel)
- NIH: P20 GM103640 and P30 GM145423 (PI: A. West)
