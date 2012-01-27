var global_port = process.env['ATOMIADNS_CONTROLPANEL_PORT'] != null ? process.env['ATOMIADNS_CONTROLPANEL_PORT'] : 5380;

var	express = require('express');
var     app = express.createServer();
var 	auth = require('./auth.js');

// Initialize the auth layer and express.
var	passport = auth.configure('/login', '/logout', app);
app.configure(function() {
	app.use(express.logger());
	app.use(express.cookieParser());
	app.use(express.bodyParser());
	app.use(express.session({ secret: auth.randomString() }));
	app.use(passport.initialize());
	app.use(passport.session());
	app.use(app.router);
	app.use(express.static(__dirname + '/static'));
});

app.get('/', auth.ensureAuthenticated, function (req, res) {
	res.render('index.jade');
});

app.listen(global_port);
