#!/bin/sh
: """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" :
This script will take the GetProductKeyViewModel.json file from an MSDN
subscription and flatten it into a list containing the product name,
its key or the remaining number of keys, and a description of the key.
: """"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""" :

infile="$1"
if [ ! -e "$infile" ]; then
    printf 'Usage: %s GetProductKeyViewModel.json\n' "$0" 1>&2
    exit 1
fi

idxfile=`mktemp`
ec=$?
if [ -z "$idxfile" ]; then
    printf '%s: Unable to create temporary file (Error %d)\n' "$0" "$ec"
    exit 1
fi

if ! jq '.groupedProductActivationByProduct | keys | map(tonumber) | sort | .[]' "$infile" >| "$idxfile"; then
    printf '%s: Unable to write index to temporary file "%s" (Error %d)\n' "$0" "$idxfile" "$?"
    rm -f "$idxfile"
    exit 1
fi

read -d '' script <<-'EOF'
	def products($index; $products) :
	    foreach $index[] as $i ([]; $products[$i | tostring])
	;
    .
	| products($index_file; .groupedProductActivationByProduct)
	| if (.
        | .staticKeys | length > 0
    ) then (.
        | {
            "name": .productFileDetail.productName,
            "description": .staticKeys[].staticKeyMetaData.productKeyDescription,
            "key": .staticKeys[].keyString
        }
	) else (.
	    | .productFileDetail as $detail
	    | .productActivationGroupedByKeyGuid as $subscription
	    | $subscription
	    | keys
	    | map(.
            | $subscription[.] as $item
            | {
                "name": $detail | .productName,
                "description": $item.productKeyMetaData.productKeyDescription,
                "remaining keys": ($item.productActivationModelBySubscriptionGuid | .[] | .remainingKeys)
            }
        )
	) end
EOF

jq --slurpfile index_file "$idxfile" "$script" "$infile" | jq -s flatten

rm -f "$idxfile"
