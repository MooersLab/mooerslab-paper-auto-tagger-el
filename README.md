![Version](https://img.shields.io/static/v1?label=mooerslab-pdf-auto-tagger-el&message=0.1&color=brightcolor)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)


# Elisp package that uses NLP to generate and add tags to PDF files of research papers

## Objective

Automate the generation and addition of tags to PDF files whose names are in a selected region in a buffer inside of Emacs.
This only works on MacOS.

## Status

Works okay. Provides a starting point. You may want to manually delete the less meaningful tags the next time that you are reading the file.

## Main Functions:

- *mooerslab-tag-papers-in-region*: Tag all PDFs listed in a region.
- *mooerslab-extract-paper-keywords*: Test keyword extraction on a single PDF.

## Features

- Preserves existing tags (appends new ones).
- Displays a detailed summary showing which papers were successfully tagged, which extraction method was used, and any errors encountered.
- Support for multiple PDF text extraction tools.
- Customizable features.

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

## Quick try

```elisp
;; 1. Save the code to a file
;; 2. In Emacs, run:
M-: (load-file "~/path/to/mooerslab-paper-auto-tagger.el")

;; 3. Test it works:
M-x mooerslab-extract-paper-keywords
```

## Permanent config

```elisp
;; 1. Save the file to a directory, e.g.,

git clone https://github.com/MooersLab/mooerslab-paper-auto-tagger-el.git ~/.emacs.d/manual-packages/mooerslab-paper-auto-tagger-el

;; 2. Add to your init.el or .emacs:
(add-to-list 'load-path "~/.emacs.d/manual-packages/mooerslab-paper-auto-tagger-el/")
(require 'mooerslab-paper-auto-tagger)

;; 3. Restart Emacs or evaluate the init file:
M-x eval-buffer RET  ; while in init.el
;; Or
M-x load-file RET ~/.emacs.d/init.el RET
```

## Customizations

```elisp
(setq mooerslab-paper-tagger-max-tags 5)        ; Number of tags to extract
(setq mooerslab-paper-tagger-python-command "python3")  ; Python command
```

## Update history

|Version      | Changes                                                                                                 | Date                |
|:-----------|:---------------------------------------------------------------------------------------------------------|:--------------------|
| Version 0.1 |   Added badges, funding, and update table.  Initial commit.                                             | 11/16/2025          |
| Version 0.2 |   Added installation instructions.  Added path to PDFs as a customizalbe variable.                      | 11/17/2025          |

## Sources of funding

- NIH: R01 CA242845
- NIH: R01 AI088011
- NIH: P30 CA225520 (PI: R. Mannel)
- NIH: P20 GM103640 and P30 GM145423 (PI: A. West)
