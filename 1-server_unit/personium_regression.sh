#!/bin/sh
#
# Shell script for checking communication
# - argument
#     $1: Unit FQDN
#
#


if [ $# -ne 1 ]; then
   echo "Usage: personium_regression.sh {FQDN}"
   echo "This argument is necessary."
   exit 1
fi


FQDN=${1}
CELL_NAME=startuptest
URL_DOMAIN=https://${FQDN}
PATH_BASED_CELL_URL=`grep "pathBasedCellUrl" /personium/personium-core/conf/18888/personium-unit-config.properties | sed -e "s/io.personium.core.pathBasedCellUrl.enabled=//"`

if [ "false" == "${PATH_BASED_CELL_URL}" ]; then
    grep ${CELL_NAME}.${FQDN} /etc/hosts > /dev/null

    if [ $? -eq 1 ]; then
      echo "127.0.0.1" ${CELL_NAME}.${FQDN} >> /etc/hosts
    fi

    CELL_URL=https://${CELL_NAME}.${FQDN}
else
    CELL_URL=https://${FQDN}/${CELL_NAME}
fi

SPECIFIED_ACCESS_TOKEN=`grep "core.masterToken" /personium/personium-core/conf/18888/personium-unit-config.properties | sed -e "s/io.personium.core.masterToken=//"`

XDCVERSION=default
CURL_LOG=/tmp/rt_curl_${XDCVERSION}.txt
RT_LOG=/tmp/rt_${XDCVERSION}.txt

# args:
#  $1: status code
#  $2: operation name
function check_response() {
  STATUS=${1}
  OPERATION=${2}
  if [ "`/bin/grep 'status:' ${CURL_LOG}`" != "status:${STATUS}" ]; then
    echo "${OPERATION} failed."
    exit 2
  fi
  if [ "default" != "${XDCVERSION}" ]; then
    RES_VERSION=`/bin/grep 'X-Personium-Version' ${CURL_LOG} | awk '{print $2}' | sed -e 's/\r//'`
    if [ `echo "${XDCVERSION}" | egrep "^${RES_VERSION}[a-z|-]+|$" | wc -l` -ne 1 ]; then
      echo "${OPERATION} failed."
      exit 2
    fi
  fi
  echo -e "`cat ${CURL_LOG}`\n\n" >> ${RT_LOG}
}

if [ "default" == "${XDCVERSION}" ]; then
  XDCVERSION_HEADER=
else
  XDCVERSION_HEADER="-H X-Personium-Version:$XDCVERSION"
fi

# If an access token is specified, use that token
# If not specified, use the latest version for acquisition
if [ "" != "${SPECIFIED_ACCESS_TOKEN}" ]; then
  ACCESSTOKEN=$SPECIFIED_ACCESS_TOKEN
else
  echo "Please specify access token"
fi

echo ${ACCESSTOKEN} >> ${RT_LOG}

echo "Delete rule" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/__ctl/Rule(Name='testRule')" -H "Accept: application/json" -H "Authorization: Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}

echo "Delete Service Source" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/col/__src/test.js" -H "Accept:application/json" -H "Content-Type: text/javascript" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}

echo "Delete Collection" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col" -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}

echo "Delete Box" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/__ctl/Box('box')" -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -H "If-Match: *" -i -k -s > ${CURL_LOG}

echo "Delete Cell" >> ${RT_LOG}
curl -w "\nstatus:%{http_code}\n" "${URL_DOMAIN}/__ctl/Cell(Name=%27${CELL_NAME}%27)" -X DELETE -H "Accept:application/json" -H "If-Match: *" -H "Authorization:Bearer $ACCESSTOKEN" -k -i -s > ${CURL_LOG}

echo "Ceate Cell" >> ${RT_LOG}
curl -w "\nstatus:%{http_code}\n" "${URL_DOMAIN}/__ctl/Cell" -X POST  -d "{\"Name\":\"${CELL_NAME}\"}" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -k -i -s > ${CURL_LOG}
check_response 201 "Ceate Cell"


echo "Get Cell" >> ${RT_LOG}
curl -w "\nstatus:%{http_code}\n" "${URL_DOMAIN}/__ctl/Cell(Name=%27${CELL_NAME}%27)" -X GET  $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -k -i -s > ${CURL_LOG}
check_response 200 "Get Cell"


echo "Create Box" >> ${RT_LOG}
curl -X POST -w "\nstatus:%{http_code}\n" "${CELL_URL}/__ctl/Box" -d "{\"Name\":\"box\"}" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 201 "Create Box"


echo "Create Service Collection" >> ${RT_LOG}
curl -X MKCOL -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col" -d "<?xml version=\"1.0\" encoding=\"utf-8\"?><D:mkcol xmlns:D=\"DAV:\" xmlns:p=\"urn:x-personium:xmlns\"><D:set><D:prop><D:resourcetype><D:collection/><p:service/></D:resourcetype></D:prop></D:set></D:mkcol>" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 201 "Create Service Collection"


echo "Register Service Source" >> ${RT_LOG}
curl -X PUT -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col/__src/test.js" -d "function(request){return {status: 200,headers: {\"Content-Type\":\"text/html\"},body: [\"hello world\"]};}" $XDCVERSION_HEADER -H "Accept:application/json" -H "Content-Type: text/javascript" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 201 "Register Service Source"


echo "Register Service" >> ${RT_LOG}
curl -X PROPPATCH -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col" -d "<?xml version=\"1.0\" encoding=\"utf-8\" ?><D:propertyupdate xmlns:D=\"DAV:\" xmlns:p=\"urn:x-personium:xmlns\" xmlns:Z=\"http:/www.w3.com/standards/z39.50/\"><D:set><D:prop><p:service language=\"JavaScript\"><p:path name=\"test\" src=\"test.js\"/></p:service></D:prop></D:set></D:propertyupdate>" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 207 "Register service"
if [ "`/bin/grep '<status>' ${CURL_LOG} | awk '{print $2}'`" != "200" ];then
  echo "Register Service faild."
  exit 2
fi

echo "Service execution" >> ${RT_LOG}
for i in `seq 1 4`
do
  curl -X GET -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col/test" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
  check_response 200 "Service execution"
  if [ "`/bin/grep 'hello world' ${CURL_LOG}`" != "hello world" ];then
    echo "Ran another script."
    exit 2
  fi
done


echo "Register rule" >> ${RT_LOG}
curl -X POST -w "\nstatus:%{http_code}\n" "${CELL_URL}/__ctl/Rule" -d "{\"Name\":\"testRule\", \"EventType\":\"test\", \"EventExternal\":true, \"Action\":\"log\"}" -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 201 "Register rule"


echo "Event receptionist" >> ${RT_LOG}
curl -X POST -w "\nstatus:%{http_code}\n" "${CELL_URL}/__event" -d "{\"Type\":\"action_value\",\"Object\":\"object_value\",\"Info\":\"result_value\"}" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 200 "Event receptionist"


echo "Get Logfile" >> ${RT_LOG}
curl -X GET -w "\nstatus:%{http_code}\n" "${CELL_URL}/__log/current/default.log" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 200 "Get Logfile"


echo "Delete rule" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/__ctl/Rule(Name='testRule')" -H "Accept: application/json" -H "Authorization: Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 204 "Delete rule"


echo "Delete Service Source" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col/__src/test.js" $XDCVERSION_HEADER -H "Accept:application/json" -H "Content-Type: text/javascript" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 204 "Delete Service Source"


echo "Delete Collection" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/box/col" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -i -k -s > ${CURL_LOG}
check_response 204 "Delete Collection"


echo "Delete Box" >> ${RT_LOG}
curl -X DELETE -w "\nstatus:%{http_code}\n" "${CELL_URL}/__ctl/Box('box')" $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -H "If-Match: *" -i -k -s > ${CURL_LOG}
check_response 204 "Delete Box"


echo "Delete Cell" >> ${RT_LOG}
curl -w "\nstatus:%{http_code}\n" "${URL_DOMAIN}/__ctl/Cell(Name=%27${CELL_NAME}%27)" -X DELETE $XDCVERSION_HEADER -H "Accept:application/json" -H "If-Match: *" -H "Authorization:Bearer $ACCESSTOKEN" -k -i -s > ${CURL_LOG}
check_response 204 "Delete Cell"


echo "Check Delete Cell" >> ${RT_LOG}
curl -w "\nstatus:%{http_code}\n" "${URL_DOMAIN}/__ctl/Cell(Name=%27${CELL_NAME}%27)" -X GET $XDCVERSION_HEADER -H "Accept:application/json" -H "Authorization:Bearer $ACCESSTOKEN" -k -i -s > ${CURL_LOG}
check_response 404 "Check Delete Cell"


echo "personium Version(${XDCVERSION}) RT OK"
echo "personium Version(${XDCVERSION}) RT OK" >> ${RT_LOG}
/bin/rm ${CURL_LOG}
exit 0
