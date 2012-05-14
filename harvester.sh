#!/bin/bash

source libs/functions.sh

# Reading repository id
if [ ! -z $1 ]; then
	REPOSITORY=$1
else
	echo "No repository id provided"
	exit 1
fi

# Reading oai repository info
if [ -f config.xml ]; then
	RECORDPATH=$(xsltproc --stringparam data recordpath libs/retrieveConfig.xsl config.xml)
	TMP=$(xsltproc --stringparam data temppath libs/retrieveConfig.xsl config.xml)
	LOGFILE=$(xsltproc --stringparam data logfile libs/retrieveConfig.xsl config.xml)
	WGET_OPTS=$(xsltproc --stringparam data wgetopts libs/retrieveConfig.xsl config.xml)
	BASEURL=$(xsltproc --stringparam data baseurl --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
	PREFIX=$(xsltproc --stringparam data metadataprefix --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
	SET=$(xsltproc --stringparam data set --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
	FROM=$(xsltproc --stringparam data from --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
	UNTIL=$(xsltproc --stringparam data until --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
	CONDITIONAL=$(xsltproc --stringparam data conditional --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
	REPOSITORY_RECORDPATH=$(xsltproc --stringparam data repository_path --stringparam repository ${REPOSITORY} libs/retrieveConfig.xsl config.xml)
else
	echo "No repository config found."
	exit 1
fi

# checking repository
if [ "${BASEURL}" == "" ]; then
	echo "No baseurl found for repository: ${REPOSITORY}"
	exit 1
fi

# determing repository record path
if [ "${REPOSITORY_RECORDPATH}" == "" ]; then
	REPOSITORY_RECORDPATH="${RECORDPATH}/${REPOSITORY}"
fi

# Making sure the repository storage and tmp dirs exists
echo "Creating repository storage in: ${REPOSITORY_RECORDPATH}"
mkdir -p "${REPOSITORY_RECORDPATH}/harvested"
mkdir -p "${REPOSITORY_RECORDPATH}/deleted"
mkdir -p ${TMP}
touch ${LOGFILE}
rm -f oaipage.xml identify.xml > /dev/null 2>&1


# Setting other arguments if set in config.
if [ "${SET}" != "" ]; then
   URI_SET="&set=${SET}"
fi
if [ "${FROM}" != "" ]; then
   URI_FROM="&from=${FROM}"
fi
if [ "${UNTIL}" != "" ]; then
   URI_UNTIL="&until=$UNTIL"
fi

# Checks for a last harvest timestamp, and uses it
# according to the granularity settings
# Overwrites repository from config setting.
repository_timestamp="${REPOSITORY_RECORDPATH}/lasttimestamp.txt"
if [ -f ${repository_timestamp} ]; then
	# check out identify for datetime granularity
	wget ${WGET_OPTS} "${BASEURL}?verb=Identify" -O identify.xml
	granularity=$(xsltproc --stringparam data granularity libs/retrieveData.xsl identify.xml)

	if [ "${granularity}" == "YYYY-MM-DDThh:mm:ssZ" ]; then
		timestamp=$(cat ${repository_timestamp})
	else
		timestamp=$(cat ${repository_timestamp} | awk -F "T" '{print $1}')
	fi
	URI_FROM="&from=${timestamp}"
fi

# Sets the initial harvest uri
URL="${BASEURL}?verb=ListRecords&metadataPrefix=${PREFIX}${URI_SET}${URI_FROM}${URI_UNTIL}"

# Now, get the initial page and the records
# if there is a resumptionToken, retrieve other pages
getRecords
RESUMPTION=$(xsltproc --stringparam data resumptiontoken libs/retrieveData.xsl oaipage.xml)

while [ "${RESUMPTION}" != "" ]; do
	URL="${BASEURL}?verb=ListRecords&resumptionToken=${RESUMPTION}"
	getRecords
	RESUMPTION=$(xsltproc --stringparam data resumptiontoken libs/retrieveData.xsl oaipage.xml)
done

# finishing up
date -u +'%FT%TZ' > ${repository_timestamp}
rm -f oaipage.xml identify.xml

exit 0
