var 	auth = require('./auth');
var 	rest = require('./rest');

exports.configure = function (app) {

	app.get('/zone/:zone', auth.ensureAuthenticated, function (req, res) {
		rest.executeOperation(req, res, req.user, "GetZone", [ req.param('zone') ], function (error, response) {
			if (!error && response == null) {
				error = "invalid JSON returned from GetZone";
			}
	
			res.render('editzone.jade', { user: req.user, name: req.param('zone'), zone: response, error: error });
		});
	});
	
	app.get('/editrecords/:zoneName', auth.ensureAuthenticated, function (req, res) {
		res.redirect('/zone/' + req.param('zoneName'));
	});

	app.post('/editrecords/:zoneName', auth.ensureAuthenticated, function (req, res) {
		var name = req.param('zoneName');

		var records = req.body.records;
		if (records != null && records.id != null && records.id instanceof Array) {
			var recordsParam = [];
			for (var idx = 0; idx < records.id.length; idx++) {
				var record = {};
				for (var key in records) {
					record[key] = records[key][idx];
				}

				recordsParam.push(record);
			}

			records = recordsParam;
		}

		rest.executeOperation(req, res, req.user, "EditDnsRecords", [ name, records ], function (error, response) {
			if (!error && response == null) {
				error = "invalid JSON returned from EditDnsRecords";
			} 
	
			rest.executeOperation(req, res, req.user, "GetZone", [ name ], function (geterror, response) {
				if (geterror || response == null) {
					error = "invalid JSON returned from GetZone";
				}
	
				res.render('editzone.jade', { user: req.user, name: name, zone: response, error: error });
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
