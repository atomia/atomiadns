var global_port = process.env['ATOMIADNS_CONTROLPANEL_PORT'] != null ? process.env['ATOMIADNS_CONTROLPANEL_PORT'] : 5380;

var	express = require('express');
var     app = express.createServer();
var 	auth = require('./auth');
var 	routes = require('./routes');

// Initialize express
var	passport = require('passport');
app.configure(function() {
	//app.use(express.logger());
	app.use(express.cookieParser());
	app.use(express.bodyParser());
	app.use(express.session({ secret: auth.randomString() }));
	app.use(passport.initialize());
	app.use(passport.session());
	app.use(app.router);
	app.use(express.static(__dirname + '/static'));
});

// Initialize the auth layer
auth.configure('/login', '/logout', app);

// Initialize the routes;
routes.configure(app);

app.listen(global_port);
