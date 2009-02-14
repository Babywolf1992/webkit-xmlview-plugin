#!/bin/bash

set -o errexit

[ ! -z $PRODUCT_SHORTNAME ] || { echo PRODUCT_SHORTNAME variable not set; false; }

[ $BUILD_STYLE = Release ] || { echo Distribution target requires "'Release'" build style; false; }

VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.$WRAPPER_EXTENSION/Contents/Info" CFBundleVersion)
DOWNLOAD_BASE_URL="http://www2.entropy.ch/download"
RELEASENOTES_URL="http://www.entropy.ch/software/macosx/$PRODUCT_SHORTNAME/release-notes.html#version-$VERSION"

ARCHIVE_FILENAME="$PRODUCT_SHORTNAME-$VERSION.zip"
ARCHIVE_FILENAME_UNVERSIONED="$PRODUCT_SHORTNAME.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="Sparkle Private Key 1"

cd "$BUILT_PRODUCTS_DIR"
rm -f "$PRODUCT_SHORTNAME"*.zip
zip -qr "$ARCHIVE_FILENAME" "$PRODUCT_NAME.$WRAPPER_EXTENSION"

echo $ARCHIVE_FILENAME "'$KEYCHAIN_PRIVKEY_NAME'"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(date +"%a, %d %b %G %T %z")
SIGNATURE=$(
	openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
	| openssl dgst -dss1 -sign <(security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g') \
	| openssl enc -base64
)

[ $SIGNATURE ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }

SRCDIRPATH="$PRODUCT_SHORTNAME-src"
rm -rf "$SRCDIRPATH"*
svn export svn+ssh://www.entropy.ch/Users/liyanage/documents/svnroot/trunk/$PRODUCT_SHORTNAME "$SRCDIRPATH"
zip -qr "$SRCDIRPATH.zip" "$SRCDIRPATH"

cat <<EOF
		<item>
			<title>Version $VERSION</title>
			<sparkle:releaseNotesLink>$RELEASENOTES_URL</sparkle:releaseNotesLink>
			<pubDate>$PUBDATE</pubDate>
			<enclosure
				url="$DOWNLOAD_URL"
				sparkle:version="$VERSION"
				type="application/octet-stream"
				length="$SIZE"
				sparkle:dsaSignature="$SIGNATURE"
			/>
		</item>
EOF

echo scp "'$HOME/svn/entropy/$PRODUCT_SHORTNAME/build/Release/$ARCHIVE_FILENAME'" www2.entropy.ch:download/
echo scp "'$HOME/svn/entropy/$PRODUCT_SHORTNAME/build/Release/$ARCHIVE_FILENAME'" "\"www2.entropy.ch:'download/$ARCHIVE_FILENAME_UNVERSIONED'\""

echo scp "'$HOME/svn/entropy/$PRODUCT_SHORTNAME/Resources/release-notes.html'" www.entropy.ch:web/software/macosx/$PRODUCT_SHORTNAME/release-notes.html
echo scp "'$BUILT_PRODUCTS_DIR/$SRCDIRPATH.zip'" www2.entropy.ch:download/
echo scp "'$HOME/svn/entropy/$PRODUCT_SHORTNAME/Resources/appcast.xml'" www.entropy.ch:web/software/macosx/$PRODUCT_SHORTNAME/appcast.xml

echo svn ci -m "'version $VERSION'"
echo svn cp -m "'tagging version $VERSION'" "svn+ssh://www.entropy.ch/Users/liyanage/documents/svnroot/trunk/$PRODUCT_SHORTNAME" "svn+ssh://www.entropy.ch/Users/liyanage/documents/svnroot/tags/$PRODUCT_SHORTNAME/versions/$VERSION"
