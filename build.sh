#!/bin/bash
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    BIN="linux/bin64"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    BIN="osx/bin"
fi

if [[ -d "dmd2" ]]; then
    DMD="./dmd2/$BIN/dmd"
else
    DMD="dmd"
fi

# debug build
$DMD -g -debug bayonet.d declaration.d error.d expression.d lexer.d parser.d scope_.d semantic_.d terminal.d translate_.d translate_prism.d translate_prism_deterministic.d util.d -ofbayonet

$DMD -g -debug maketable.d -ofmaketable
