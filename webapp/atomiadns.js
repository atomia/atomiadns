var global_port = process.env['WEBAPP_LISTEN_PORT'] != null ? process.env['WEBAPP_LISTEN_PORT'] : 5380;

var	express = require('express');
var     app = express();
var 	auth = require('./auth');
var 	routes = require('./routes');

// Initialize express
var	passport = require('passport');
app.configure(function() {
	//app.use(express.logger());
	app.set('views', __dirname + '/views');
	app.set('view options', {
		layout: false
	});

	app.use(express.cookieParser());
	app.use(express.bodyParser());
	app.use(express.session({ secret: auth.randomString() }));
	app.use(passport.initialize());
	app.use(passport.session());
	app.use(express.static(__dirname + '/static'));
	app.use(app.router);
});

// Initialize the auth layer
auth.configure('/login', '/logout', app);

// Initialize the routes;
routes.configure(app);

app.listen(global_port);
