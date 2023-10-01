#/bin/sh

directory="${SRCROOT:-"."}"
cd "${directory}"/..

# TAGS="TODO:|FIXME:"
# find . -type f \( -name "*.h" -or -name "*.m" -or -name "*.swift" \) -not -path "./Tuist/*" -not -path "./.build/*" -print0 | xargs -0 egrep --with-filename --line-number --only-matching "${TAGS}\.$" | perl -p -e "s/${TAGS}/ warning: \$1/"

# sh ./ci_scripts/cpd_run.sh && echo "CPD done"

cat periphery.log | grep -v -e "Property 'inject'" -e "Property 'store'" || true
# periphery scan > periphery.log &

cat swiftlint_analyze.log || true
php ci_scripts/cpd_script.php -cpd-xml cpd-output.xml || true
