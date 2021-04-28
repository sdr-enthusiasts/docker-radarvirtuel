#!/bin/bash

# from here: https://stackoverflow.com/questions/57446494/how-to-parse-yaml-data-into-a-custom-bash-data-array-hash-structure
#
# usage yay yaml_file.yml

function yaml_to_vars {
   # find input file
   for f in "$1" "$1.yay" "$1.yml"
   do
     [[ -f "$f" ]] && input="$f" && break
   done
   [[ -z "$input" ]] && exit 1

   # use given dataset prefix or imply from file name
   [[ -n "$2" ]] && local prefix="$2" || {
     local prefix=$(basename "$input"); prefix=${prefix%.*}; prefix="${prefix//-/_}_";
   }

   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
   sed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
        -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
      if(length($2)== 0){  vname[indent]= ++idx[indent] };
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], $3);
      }
   }'
}

yay_parse() {

   # find input file
   for f in "$1" "$1.yay" "$1.yml"
   do
     [[ -f "$f" ]] && input="$f" && break
   done
   [[ -z "$input" ]] && exit 1

   # use given dataset prefix or imply from file name
   [[ -n "$2" ]] && local prefix="$2" || {
     local prefix=$(basename "$input"); prefix=${prefix%.*}; prefix=${prefix//-/_};
   }

   echo "unset $prefix; declare -g -a $prefix;"

   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   #sed -n -e "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
   #       -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" "$input" |
   sed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
   sed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
        -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
   awk -F$fs '{
      indent       = length($1)/2;
      key          = $2;
      value        = $3;

      # No prefix or parent for the top level (indent zero)
      root_prefix  = "'$prefix'_";
      if (indent == 0) {
        prefix = "";          parent_key = "'$prefix'";
      } else {
        prefix = root_prefix; parent_key = keys[indent-1];
      }

      keys[indent] = key;

      # remove keys left behind if prior row was indented more than this row
      for (i in keys) {if (i > indent) {delete keys[i]}}

      # if we have a value
      if (length(value) > 0) {

        # set values here

        # if the "key" is missing, make array indexed, not assoc..

        if (length(key) == 0) {
          # array item has no key, only a value..
          # so, if we didnt already unset the assoc array
          if (unsetArray == 0) {
            # unset the assoc array here
            printf("unset %s%s; ", prefix, parent_key);
            # switch the flag, so we only unset once, before adding values
            unsetArray = 1;
          }
          # array was unset, has no key, so add item using indexed array syntax
          printf("%s%s+=(\"%s\");\n", prefix, parent_key, value);

        } else {
          # array item has key and value, add item using assoc array syntax
          printf("%s%s[%s]=\"%s\";\n", prefix, parent_key, key, value);
        }

      } else {

        # declare arrays here

        # reset this flag for each new array we work on...
        unsetArray = 0;

        # if item has no key, declare indexed array
        if (length(key) == 0) {
          # indexed
          printf("unset %s%s; declare -g -a %s%s;\n", root_prefix, key, root_prefix, key);

        # if item has numeric key, declare indexed array
        } else if (key ~ /^[[:digit:]]/) {
          printf("unset %s%s; declare -g -a %s%s;\n", root_prefix, key, root_prefix, key);

        # else (item has a string for a key), declare associative array
        } else {
          printf("unset %s%s; declare -g -A %s%s;\n", root_prefix, key, root_prefix, key);
        }

        # set root level values here

        if (indent > 0) {
          # add to associative array
          printf("%s%s[%s]+=\"%s%s\";\n", prefix, parent_key , key, root_prefix, key);
        } else {
          # add to indexed array
          printf("%s%s+=( \"%s%s\");\n", prefix, parent_key , root_prefix, key);
        }

      }
   }'
}

# helper to load yay data file
yay() {
  # yaml_to_vars "$@"  ## uncomment to debug (prints data to stdout)
  eval $(yaml_to_vars "$@")

  # yay_parse "$@"  ## uncomment to debug (prints data to stdout)
  eval $(yay_parse "$@")
}
