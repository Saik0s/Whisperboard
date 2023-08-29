<?php
foreach (simplexml_load_file('cpd-output.xml')->duplication as $duplication) {
    $files = $duplication->xpath('file');
    foreach ($files as $file) {
        echo $file['path'].':'.$file['line'].':1: warning: '.$duplication['lines'].' copy-pasted lines from: '
            .implode(', ', array_map(function ($otherFile) { return $otherFile['path'].':'.$otherFile['line']; },
            array_filter($files, function ($f) use (&$file) { return $f != $file; }))).PHP_EOL;
    }
}
?>
