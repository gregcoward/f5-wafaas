var request = require('request');
var crypto = require('crypto');

// Azure Log Analysis credentials
var workspaceId = '0f676980-a32a-47a8-82c4-b84b24a938d3';
var sharedKey = 'YZi6RA5jCqWV8oTvYaGSHNPzJc+9vHNjcdZzEJPMNhj+0rWfgOqPJB1YUuYw3nLBh0XGRKPPlroYvRANZVeygQ==';

var apiVersion = '2016-04-01';
var processingDate = "Tue, 01 Aug 2017 08:13:45 GMT";

var jsonData = [{
        "time": "Tue, 01 Aug 2017 08:13:45 GMT",
        "host": "f5wafaas020.westus.cloudapp.azure.com",
        "logSource": "ASM",
        "bigipVersion": "12.1.2",
        "sourceIp": "12.219.84.8",
        "sourcePort": "29182",
        "reason": "Non-browser Client",
        "action": "Blocked",
        "supportId": "1420133427503437521",
        "remediationLink": "https://f5wafaas020.westus.cloudapp.azure.com:8443/dms/policy/win_open_proxy_request.php?id=&support_id=1420133427503437521"
    }];

var body = JSON.stringify(jsonData);
console.log('body:', body);

var contentLength = Buffer.byteLength(body, 'utf8');

var stringToSign = 'POST\n' + contentLength + '\napplication/json\nx-ms-date:' + processingDate + '\n/api/logs';
var signature = crypto.createHmac('sha256', new Buffer(sharedKey, 'base64')).update(stringToSign, 'utf-8').digest('base64');
var authorization = 'SharedKey ' + workspaceId + ':' + signature;
console.log('authorization: ', authorization);

var headers = {
    "content-type": "application/json",
    "Authorization": authorization,
    "Log-Type": 'WebMonitorTest',
    "x-ms-date": processingDate
};

var url = 'https://' + workspaceId + '.ods.opinsights.azure.com/api/logs?api-version=' + apiVersion;

request.post({ url: url, headers: headers, body: body }, function (error, response, body) {
    console.log('error:', error);
    console.log('statusCode:', response && response.statusCode);
    console.log('body:', body);
});