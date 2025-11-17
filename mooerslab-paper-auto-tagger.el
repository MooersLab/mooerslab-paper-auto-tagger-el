;;; mooerslab-paper-auto-tagger.el --- Automatically tag research paper PDFs with OCR-extracted keywords

;;; Commentary:
;; This package automatically generates and applies tags to research paper PDF files
;; on macOS. It uses OCR to extract keywords from the paper, falling back to
;; title/abstract analysis if needed.

;; Copyright (C) 2025 Blaine Mooers and the University of Oklahoma Board of Regents

;; Author: blaine-mooers@ou.edu
;; Maintainer: blaine-mooers@ou.edu
;; URL: https://github.com/MooersLab/mooerslab-pdf-auto-tagger-el
;; Version: 0.1
;; Keywords: pdf, tags, automation, MacOS
;; License: MIT
;; Updated 2025 November 16

;;; Code:

(require 'json)

(defcustom mooerslab-paper-tagger-python-command "python3"
  "Command to invoke Python 3."
  :type 'string
  :group 'mooerslab-paper-tagger)

(defcustom mooerslab-paper-tagger-max-tags 5
  "Maximum number of tags to generate per paper."
  :type 'integer
  :group 'mooerslab-paper-tagger)

(defcustom mooerslab-paper-tagger-ocr-backend 'tesseract
  "OCR backend to use. Options: tesseract, pdftotext."
  :type '(choice (const :tag "Tesseract OCR" tesseract)
                 (const :tag "PDFtotext" pdftotext))
  :group 'mooerslab-paper-tagger)

(defvar mooerslab-paper-tagger-python-script
  "#!/usr/bin/env python3
import sys
import json
import re
from collections import Counter
import subprocess
import os

def extract_text_from_pdf(pdf_path, max_pages=2):
    \"\"\"Extract text from first few pages of PDF using pdftotext.\"\"\"
    try:
        # Try pdftotext first (faster and usually better)
        result = subprocess.run(
            ['pdftotext', '-l', str(max_pages), '-layout', pdf_path, '-'],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    
    # Fallback to PyPDF2
    try:
        import PyPDF2
        text = ''
        with open(pdf_path, 'rb') as file:
            reader = PyPDF2.PdfReader(file)
            num_pages = min(max_pages, len(reader.pages))
            for i in range(num_pages):
                text += reader.pages[i].extract_text()
        return text
    except Exception as e:
        return None

def extract_keywords_from_text(text):
    \"\"\"Extract keywords section from paper text.\"\"\"
    if not text:
        return None
    
    # Common patterns for keywords section
    patterns = [
        r'(?i)keywords?\\s*[:\\-]?\\s*([^\\n]+(?:\\n[^\\n]{0,80})?)',
        r'(?i)key\\s*words?\\s*[:\\-]?\\s*([^\\n]+(?:\\n[^\\n]{0,80})?)',
        r'(?i)index\\s*terms?\\s*[:\\-]?\\s*([^\\n]+(?:\\n[^\\n]{0,80})?)',
    ]
    
    for pattern in patterns:
        match = re.search(pattern, text)
        if match:
            keywords_text = match.group(1)
            # Clean and split keywords
            keywords = re.split(r'[;,·•]|\\band\\b', keywords_text)
            keywords = [k.strip() for k in keywords if k.strip()]
            # Remove common noise
            keywords = [k for k in keywords if len(k) > 2 and len(k) < 50]
            return keywords[:5] if keywords else None
    
    return None

def extract_title_abstract(text):
    \"\"\"Extract title and abstract from paper text.\"\"\"
    if not text:
        return None, None
    
    lines = text.split('\\n')
    lines = [l.strip() for l in lines if l.strip()]
    
    # Try to find title (usually in first few lines, may be all caps or title case)
    title = None
    title_end = 0
    for i, line in enumerate(lines[:10]):
        if len(line) > 10 and len(line) < 200:
            # Skip common header text
            if re.search(r'(?i)(journal|proceedings|conference|volume|doi:|arxiv)', line):
                continue
            if not title:
                title = line
                title_end = i
            elif len(line) > 20:  # Multi-line title
                title += ' ' + line
                title_end = i
            else:
                break
    
    # Try to find abstract
    abstract = None
    abstract_patterns = [
        r'(?i)(?:^|\\n)\\s*abstract\\s*[:\\-]?\\s*(.+?)(?=\\n\\s*(?:introduction|keywords?|1\\.|I\\.))',
        r'(?i)(?:^|\\n)\\s*abstract\\s*[:\\-]?\\s*(.+?)(?=\\n\\n)',
    ]
    
    for pattern in abstract_patterns:
        match = re.search(pattern, text, re.DOTALL)
        if match:
            abstract = match.group(1).strip()
            # Limit abstract length
            if len(abstract) > 2000:
                abstract = abstract[:2000]
            break
    
    return title, abstract

def extract_keywords_from_title_abstract(title, abstract, max_keywords=5):
    \"\"\"Extract keywords from title and abstract using NLP or simple methods.\"\"\"
    try:
        import spacy
        try:
            nlp = spacy.load('en_core_web_sm')
        except OSError:
            # Fall back to simple extraction
            return simple_keyword_extraction(title, abstract, max_keywords)
        
        # Combine title and abstract
        text = ''
        if title:
            text += title + '. '
        if abstract:
            text += abstract
        
        if not text.strip():
            return []
        
        doc = nlp(text)
        
        # Extract noun phrases and important terms
        keywords = []
        
        # Get noun chunks
        for chunk in doc.noun_chunks:
            if len(chunk.text.split()) <= 3:  # Limit to 3-word phrases
                keywords.append(chunk.text.lower())
        
        # Get named entities
        for ent in doc.ents:
            if ent.label_ in ['ORG', 'PRODUCT', 'WORK_OF_ART', 'EVENT', 'GPE']:
                keywords.append(ent.text.lower())
        
        # Get important nouns and proper nouns
        for token in doc:
            if token.pos_ in ['NOUN', 'PROPN'] and not token.is_stop and len(token.text) > 2:
                keywords.append(token.lemma_.lower())
        
        # Count frequency
        keyword_freq = Counter(keywords)
        
        # Get most common, filtering out very common words
        stop_words = {'paper', 'study', 'research', 'article', 'work', 'approach', 
                     'method', 'result', 'conclusion', 'introduction', 'section'}
        
        filtered_keywords = [
            kw.replace(' ', '-') for kw, count in keyword_freq.most_common(max_keywords * 3)
            if kw not in stop_words and len(kw) > 2
        ]
        
        return filtered_keywords[:max_keywords]
    
    except ImportError:
        return simple_keyword_extraction(title, abstract, max_keywords)

def simple_keyword_extraction(title, abstract, max_keywords=5):
    \"\"\"Simple keyword extraction without NLP libraries.\"\"\"
    # Common academic stop words
    stop_words = {
        'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
        'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
        'we', 'our', 'this', 'that', 'these', 'those', 'is', 'are', 'was', 'were',
        'been', 'be', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would',
        'could', 'should', 'may', 'might', 'must', 'can', 'paper', 'study',
        'research', 'article', 'work', 'approach', 'method', 'result', 'results',
        'conclusion', 'introduction', 'section', 'figure', 'table', 'show', 'shows',
        'using', 'used', 'based', 'present', 'presents', 'propose', 'proposed'
    }
    
    text = ''
    if title:
        text += title + ' '
    if abstract:
        text += abstract
    
    # Extract words
    words = re.findall(r'\\b[a-z][a-z]+\\b', text.lower())
    
    # Count frequencies
    word_freq = Counter(w for w in words if w not in stop_words and len(w) > 3)
    
    # Get most common
    keywords = [word for word, count in word_freq.most_common(max_keywords)]
    
    return keywords

def process_pdf(pdf_path, max_keywords=5):
    \"\"\"Main function to process a PDF and extract keywords.\"\"\"
    result = {
        'file': os.path.basename(pdf_path),
        'keywords': [],
        'method': 'none',
        'error': None
    }
    
    try:
        # Extract text from PDF
        text = extract_text_from_pdf(pdf_path)
        
        if not text:
            result['error'] = 'Could not extract text from PDF'
            return result
        
        # Method 1: Try to find keywords section
        keywords = extract_keywords_from_text(text)
        if keywords and len(keywords) >= 3:
            result['keywords'] = keywords[:max_keywords]
            result['method'] = 'ocr-keywords'
            return result
        
        # Method 2: Extract from title and abstract
        title, abstract = extract_title_abstract(text)
        
        if title or abstract:
            keywords = extract_keywords_from_title_abstract(title, abstract, max_keywords)
            if keywords:
                result['keywords'] = keywords
                result['method'] = 'title-abstract'
                return result
        
        result['error'] = 'Could not extract sufficient keywords'
        return result
    
    except Exception as e:
        result['error'] = str(e)
        return result

def main():
    if len(sys.argv) != 3:
        print(json.dumps({'error': 'Usage: script.py <pdf_path> <max_keywords>'}))
        sys.exit(1)
    
    pdf_path = sys.argv[1]
    max_keywords = int(sys.argv[2])
    
    result = process_pdf(pdf_path, max_keywords)
    print(json.dumps(result))

if __name__ == '__main__':
    main()
"
  "Python script for extracting keywords from research papers.")

(defun mooerslab-paper-tagger--check-dependencies ()
  "Check if required dependencies are installed."
  (let ((missing '()))
    ;; Check for Python
    (unless (executable-find mooerslab-paper-tagger-python-command)
      (push "Python 3" missing))
    
    ;; Check for pdftotext (poppler-utils)
    (unless (executable-find "pdftotext")
      (message "Warning: pdftotext not found. Install poppler-utils for better performance."))
    
    ;; Check for tag command (macOS)
    (when (eq system-type 'darwin)
      (unless (executable-find "tag")
        (push "macOS 'tag' command" missing)))
    
    (when missing
      (user-error "Missing dependencies: %s" (string-join missing ", ")))
    t))

    (defun mooerslab-paper-tagger--extract-keywords-python (pdf-path)
      "Extract keywords from PDF-PATH using Python script.
    Returns a plist with :keywords, :method, and :error keys."
      (let* ((temp-script (make-temp-file "paper-tagger" nil ".py"))
             result)
        (unwind-protect
            (progn
              ;; Write Python script to temp file
              (with-temp-file temp-script
                (insert mooerslab-paper-tagger-python-script))
          
              ;; Make file executable using chmod
              (set-file-modes temp-script #o755)
          
              ;; Execute Python script
              (let* ((output (shell-command-to-string
                             (format "%s %s '%s' %d 2>&1"
                                    mooerslab-paper-tagger-python-command
                                    (shell-quote-argument temp-script)
                                    pdf-path
                                    mooerslab-paper-tagger-max-tags)))
                     (parsed (condition-case err
                                (json-read-from-string output)
                              (error
                               (message "Error parsing JSON: %s\nOutput: %s" err output)
                               nil))))
                (when parsed
                  (setq result (list :keywords (append (cdr (assoc 'keywords parsed)) nil)
                                   :method (cdr (assoc 'method parsed))
                                   :error (cdr (assoc 'error parsed)))))))
          ;; Clean up temp file
          (delete-file temp-script))
        result))

(defun mooerslab-paper-tagger--apply-tags-macos (filepath tags)
  "Apply TAGS to FILEPATH using macOS tag command, preserving existing tags.
Returns t on success, nil on failure."
  (when (and filepath tags (file-exists-p filepath))
    (let* ((tag-string (mapconcat #'identity tags ","))
           ;; Use -a flag to add/append tags, preserving existing ones
           (command (format "tag -a '%s' '%s'"
                           tag-string
                           (expand-file-name filepath)))
           (result (shell-command command)))
      (= result 0))))

(defun mooerslab-paper-tagger--get-existing-tags (filepath)
  "Get existing tags from FILEPATH on macOS.
Returns a list of tag strings."
  (when (file-exists-p filepath)
    (let* ((command (format "tag -l '%s'" (expand-file-name filepath)))
           (output (string-trim (shell-command-to-string command))))
      (when (and output (not (string-empty-p output)))
        (split-string output "\n" t)))))

;;;###autoload
(defun mooerslab-tag-papers-in-region (path-to-files)
  "Tag research paper PDFs listed in region with automatically extracted keywords.
PATH-TO-FILES is the directory path where the PDF files are located.
Each line in the region should contain a PDF filename.

The function will:
1. Use OCR to extract text from the first pages of each PDF
2. Try to find keywords section in the paper
3. If not found, extract keywords from title and abstract
4. Apply these tags to the PDF files on macOS (preserving existing tags)

Requires macOS with 'tag' command and Python 3.
Recommended: pdftotext (poppler-utils) for better text extraction.
Optional: spaCy for better keyword extraction (pip install spacy)."
  (interactive "DPath to PDF files: ")
  
  ;; Check dependencies
  (mooerslab-paper-tagger--check-dependencies)
  
  (unless (use-region-p)
    (user-error "No region selected"))
  
  (let* ((start (region-beginning))
         (end (region-end))
         (lines (split-string (buffer-substring-no-properties start end) "\n" t))
         (results '())
         (success-count 0)
         (failure-count 0)
         (total (length lines)))
    
    (message "Processing %d papers..." total)
    
    (dolist (line lines)
      (let* ((filename (string-trim line))
             (filepath (expand-file-name filename path-to-files)))
        
        (if (file-exists-p filepath)
            (progn
              (message "Processing: %s (%d/%d)" filename 
                      (1+ (length results)) total)
              
              (let* ((existing-tags (mooerslab-paper-tagger--get-existing-tags filepath))
                     (extraction-result (mooerslab-paper-tagger--extract-keywords-python filepath))
                     (keywords (plist-get extraction-result :keywords))
                     (method (plist-get extraction-result :method))
                     (error-msg (plist-get extraction-result :error)))
                
                (if (and keywords (> (length keywords) 0))
                    (progn
                      (message "  Found %d keywords via %s: %s" 
                              (length keywords) method
                              (mapconcat #'identity keywords ", "))
                      
                      (if (mooerslab-paper-tagger--apply-tags-macos filepath keywords)
                          (progn
                            (setq success-count (1+ success-count))
                            (push (list :file filename
                                      :existing-tags existing-tags
                                      :new-tags keywords
                                      :method method
                                      :status 'success)
                                  results))
                        (setq failure-count (1+ failure-count))
                        (push (list :file filename
                                  :status 'failed
                                  :reason "Could not apply tags")
                              results)))
                  (progn
                    (setq failure-count (1+ failure-count))
                    (push (list :file filename
                              :status 'failed
                              :reason (or error-msg "No keywords extracted"))
                          results)))))
          (setq failure-count (1+ failure-count))
          (push (list :file filename
                    :status 'failed
                    :reason "File not found")
                results))))
    
    ;; Display summary
    (let ((summary-buffer (get-buffer-create "*Paper Tagging Results*")))
      (with-current-buffer summary-buffer
        (erase-buffer)
        (insert (format "Research Paper Tagging Summary\n"))
        (insert (format "================================\n\n"))
        (insert (format "Total papers: %d\n" total))
        (insert (format "Successfully tagged: %d\n" success-count))
        (insert (format "Failed: %d\n\n" failure-count))
        (insert "Details:\n")
        (insert "--------\n\n")
        
        (dolist (result (reverse results))
          (let ((file (plist-get result :file))
                (status (plist-get result :status))
                (method (plist-get result :method))
                (existing-tags (plist-get result :existing-tags))
                (new-tags (plist-get result :new-tags))
                (reason (plist-get result :reason)))
            (insert (format "File: %s\n" file))
            (insert (format "Status: %s\n" status))
            (when method
              (insert (format "Extraction method: %s\n" method)))
            (when existing-tags
              (insert (format "Existing tags: %s\n" 
                            (mapconcat #'identity existing-tags ", "))))
            (when new-tags
              (insert (format "New tags: %s\n" 
                            (mapconcat #'identity new-tags ", "))))
            (when reason
              (insert (format "Reason: %s\n" reason)))
            (insert "\n"))))
      
      (display-buffer summary-buffer)
      (message "Tagging complete. %d succeeded, %d failed." 
               success-count failure-count))))

;;;###autoload
(defun mooerslab-extract-paper-keywords (pdf-file)
  "Extract and display keywords from a single PDF-FILE.
Useful for testing keyword extraction."
  (interactive "fPDF file: ")
  (mooerslab-paper-tagger--check-dependencies)
  
  (message "Extracting keywords from %s..." (file-name-nondirectory pdf-file))
  
  (let* ((result (mooerslab-paper-tagger--extract-keywords-python pdf-file))
         (keywords (plist-get result :keywords))
         (method (plist-get result :method))
         (error-msg (plist-get result :error)))
    
    (if keywords
        (message "Keywords (via %s): %s" method (mapconcat #'identity keywords ", "))
      (message "Failed to extract keywords: %s" (or error-msg "Unknown error")))))

(provide 'mooerslab-paper-auto-tagger)
;;; mooerslab-paper-auto-tagger.el ends here