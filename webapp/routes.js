var 	auth = require('./auth');
var 	rest = require('./rest');

exports.configure = function (app) {

	app.get('/css/', function (req, res) {
		res.contentType('text/css');
		res.sendfile('css/atomiadns.css');
	});

	app.get('/zone/:zone', auth.ensureAuthenticated, function (req, res) {
		rest.executeOperation(req, res, req.user, "GetZone", [ req.param('zone') ], function (error, response) {
			if (!error && response == null) {
				error = "invalid JSON returned from GetZone";
			}
	
			res.render('editzone.jade', { user: req.user, name: req.param('zone'), zone: response, error: error });
		});
	});

	app.get('/addzone', auth.ensureAuthenticated, function (req, res) {
		res.render('addzone.jade', { user: req.user, name: "", error: null });
	});

	app.post('/addzone', auth.ensureAuthenticated, function (req, res) {
		var name = req.body.name;
		var copyFrom = req.body.copyFrom;

		var soa = rest.defaultSOAValues.slice(0);
		soa.unshift(name);
		soa.push(rest.defaultNameservers);
		soa.push(rest.nameserverGroupName);

		rest.executeOperation(req, res, req.user, "AddZone", soa, function (error, response) {
			if (error) {
				res.render('addzone.jade', { user: req.user, name: name, error: error });
			} else if (copyFrom != null && copyFrom.length > 0) {
				rest.executeOperation(req, res, req.user, "GetZoneBinary", [ copyFrom ], function (error, response) {
					if (error) {
						res.render('addzone.jade', { user: req.user, name: name, error: error });
					} else {
						rest.executeOperation(req, res, req.user, "RestoreZoneBinary",
							[ name, rest.nameserverGroupName, response ], function (error, response) {

							if (error) {
								res.render('addzone.jade', { user: req.user, name: name, error: error });
							} else {
								res.redirect('/');
							}
						});
					}
				});
			} else {
				res.redirect('/');
			}
		});
	});

	app.get('/exportzone/:zoneName', auth.ensureAuthenticated, function (req, res) {
		var name = req.param('zoneName');

		rest.executeOperation(req, res, req.user, "GetZoneBinary", [ name ], function (error, response) {
			res.render('exportzone.jade', { user: req.user, name: name, zone: response, error: error });
		});
	});

	app.get('/importzone/:zoneName', auth.ensureAuthenticated, function (req, res) {
		res.render('importzone.jade', { user: req.user, name: req.param('zoneName'), error: null });
	});

	app.post('/importzone/:zoneName', auth.ensureAuthenticated, function (req, res) {
		var name = req.param('zoneName');

		rest.executeOperation(req, res, req.user, "RestoreZoneBinary", [ name, rest.nameserverGroupName, req.body.zone.replace(/\r/g, '') ], function (error, response) {
			if (error) {
				res.render('importzone.jade', { user: req.user, name: name, zone: req.body.zone, error: error });
			} else {
				res.redirect('/');
			}
		});
	});

	app.get('/delzone/:zoneName', auth.ensureAuthenticated, function (req, res) {
		rest.executeOperation(req, res, req.user, "DeleteZone", [ req.param('zoneName') ], function (error, response) {
			if (error) {
				res.render('error.jade', { user: req.user, error: error });
			} else {
				res.redirect('/');
			}
		});
	});

	app.get('/deleterecord/:zoneName/:id', auth.ensureAuthenticated, function (req, res) {
		var name = req.param('zoneName');

		rest.executeOperation(req, res, req.user, "DeleteDnsRecords", [ name, [ { id: req.param('id'), class: 'IN', type: 'A', ttl: 3600, rdata: '127.0.0.1', label: 'foo' } ] ], function (error, response) {
			rest.executeOperation(req, res, req.user, "GetZone", [ name ], function (geterror, response) {
				if (geterror || response == null) {
					error = "invalid JSON returned from GetZone";
				}
	
				res.render('editzone.jade', { user: req.user, name: name, zone: response, error: error });
			});
		});
	});
	
	app.get('/editrecords/:zoneName', auth.ensureAuthenticated, function (req, res) {
		res.redirect('/zone/' + req.param('zoneName'));
	});

	app.post('/editrecords/:zoneName', auth.ensureAuthenticated, function (req, res) {
		var name = req.param('zoneName');

		var records = req.body.records;
		var newrecords = req.body.newrecords;

		if (records != null && records.id != null && records.id instanceof Array && newrecords != null && newrecords.id != null && newrecords.id instanceof Array) {
			var recordsParam = [];
			for (var idx = 0; idx < records.id.length; idx++) {
				var record = {};
				for (var key in records) {
					record[key] = records[key][idx];
				}

				recordsParam.push(record);
			}
			records = recordsParam;

			var newRecordsParam = [];
			for (var idx = 0; idx < newrecords.id.length; idx++) {
				var record = {};
				for (var key in newrecords) {
					record[key] = newrecords[key][idx];
				}

				if (record.type != null && record.type.length) {
					newRecordsParam.push(record);
				}
			}
			newrecords = newRecordsParam;
		}

		rest.executeOperation(req, res, req.user, "EditDnsRecords", [ name, records ], function (error, response) {
			rest.executeOperation(req, res, req.user, "AddDnsRecords", [ name, newrecords ], function (adderror, response) {
				if (!adderror) {
					error = adderror;
				}
	
				rest.executeOperation(req, res, req.user, "GetZone", [ name ], function (geterror, response) {
					if (geterror || response == null) {
						error = "invalid JSON returned from GetZone";
					}
	
					res.render('editzone.jade', { user: req.user, name: name, zone: response, error: error });
				});
			});
		});
	});
	
	app.get('/:offset?/:count?', auth.ensureAuthenticated, function (req, res) {
		var offset = req.param('offset', 0);
		var count = req.param('count', 10);
		rest.executeOperation(req, res, req.user, "FindZones", [ req.user.email, '%', count, offset ], function (error, response) {
			var total = null;
			var zones = null;
			if (!error && response != null && response.total != null && response.zones != null) { 
				total = response.total;
				zones = response.zones;
			} else if (!error) {
				error = "invalid JSON returned from FindZones";
			}
	
			res.render('index.jade', { user: req.user, total: total, offset: offset, count: count, zones: zones, error: error });
		});
	});

};
