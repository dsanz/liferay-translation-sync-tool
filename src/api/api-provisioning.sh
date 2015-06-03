regex="/([^/]+)/docroot/WEB-INF/src";
for f in $(find -wholename "*/docroot/WEB-INF/src/content/Language.properties"); do
	[[ $f =~ $regex ]];
	echo "$f --> ${BASH_REMATCH[1]}";
done


regex="/([^/]+)/docroot/WEB-INF/src";
for f in $(find -wholename "*/docroot/WEB-INF/src/content/Language.properties"); do
	[[ $f =~ $regex ]];
	echo "$f --> ${BASH_REMATCH[1]}";
done
