var request = require('request');

module.exports.getOperationRequest = function getOperationRequest(operation, username, token, password) {
	var uri_base = process.env['ATOMIADNS_SOAP_URI'] != null ? process.env['ATOMIADNS_SOAP_URI'] : "http://127.0.0.1/atomiadns.json/"
	if (uri_base.lastIndexOf('/') != uri_base.length) {
		uri_base += "/";
	}

	var headers_dict = {
		"X-Auth-Username": username
	};

	if (token != null) {
		headers_dict["X-Auth-Token"] = token;
	} else if (password != null) {
		headers_dict["X-Auth-Password"] = password;
	}

	return {
		uri: uri_base + operation,
		headers: headers_dict
	};
};

module.exports.authenticate = function authenticate(username, password, callback) {
	request.post(module.exports.getOperationRequest("Noop", username, null, password), function (error, res, body) {
		if (error) return callback(error);
		if (res.statusCode == 200) {
			var token = res.headers['X-Auth-Token'];
			return callback(null, token)
		} else {
			return callback("authentication failed, status code from rest api was " + res.statusCode);
		}
	});
};

module.exports.executeOperation(req, res, operation, user, callback) {
	if (operation == null || user == null || user.email == null || user.token == null) {
		return callback("invalid input to executeOperation");
	}

	var args = Array.prototype.slice.call(arguments, 2);

	var operationReq = module.exports.getOperationRequest(operation, user.email, user.token);
	operationReq.body = JSON.stringify(args);

	request.post(operationReq, function (error, res, body) {
		if (error) return callback(error);
		if (res.statusCode == 200) {
			try {
				var operationResponse = JSON.parse(body);
				return callback(null, operationResponse)
			} catch (e) {
				return callback("invalid JSON returned for " + operation);
			}
		} else if (res.statusCode >= 400 && res.statusCode < 500) {
			req.logout();
			res.redirect(req.url);
			return;
		} else {
			return callback("invalid status for " + operation);
		}
	});
};
