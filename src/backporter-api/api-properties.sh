#!/bin/bash

# key prefix for new (source) english key names
declare -g new_english="N";
# key prefix for old (target) english key names
declare -g old_english="O";
# key prefix for new (source) language key names
declare -g new_lang="n";
# key prefix for old (target) language key names
declare -g old_lang="o";

function english_value_changed() {
	value_changed $new_english $old_english $1
}
function lang_value_changed() {
	value_changed $new_lang $old_lang $1
}
function exists_in_new() {
	exists_key $new_english $1
}
function exists_in_old() {
	exists_key $old_english $1
}