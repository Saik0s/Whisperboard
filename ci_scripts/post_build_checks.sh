#/bin/sh

directory="${SRCROOT:-"."}"
cd "${directory}"/..
TAGS="TODO:|FIXME:"
find . -type f \( -name "*.h" -or -name "*.m" -or -name "*.swift" \) -not -path "./Tuist/*" -not -path "./.build/*" -print0 | xargs -0 egrep --with-filename --line-number --only-matching "${TAGS}\.$" | perl -p -e "s/${TAGS}/ warning: \$1/"
cat periphery.log | grep -v -e "Property 'inject'" -e "Property 'store'" || true
cat swiftlint_analyze.log || true
php ci_scripts/cpd_script.php -cpd-xml cpd-output.xml || true
