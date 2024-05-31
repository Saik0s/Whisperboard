#!/bin/sh

# brew install pmd

PATH=$PATH:/opt/homebrew/bin

# Running CPD
pmd cpd --dir Sources --minimum-tokens 50 --language swift --encoding UTF-8 --format net.sourceforge.pmd.cpd.XMLRenderer > cpd-output.xml

# Running script
php ./ci_scripts/cpd_script.php -cpd-xml cpd-output.xml
