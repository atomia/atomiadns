var	passport = require('passport'),
	LocalStrategy = require('passport-local').Strategy;

module.exports.configure = function configure(login_url, logout_url, app) {
	passport.serializeUser(function(user, callback) {
		done(null, user);
	});

	passport.deserializeUser(function(user, done) {
		done(null, user);
	});

	passport.use(new LocalStrategy(
		function(username, password, callback) {
			// auth username/pass and return { email: "email@email", token: "authtoken" }
			return callback(null, false);
		}));

	app.get(login_url + "/:targetURL", function (req, res, next) {
		res.render('login.jade', { user: req.user });
	});

	app.post(login_url + "/:targetURL", function (req, res, next) {
		var target = req.param("targetURL", "/");
		passport.authenticate('local', {
			failureRedirect: login_url + "/" + encodeURIComponent(target),
			successRedirect: target
		}
		)(req, res, next);
	});

	app.get(logout_url, function (req, res) {
		req.logout();
		res.redirect('/');
	});

	module.exports.ensureAuthenticated = function ensureAuthenticated(req, res, next) {
		if (req.isAuthenticated()) { return next(); }
		res.redirect(login_url + "/" + encodeURIComponent(req.url));
	};

	return passport;
};

module.exports.randomString = function randomString() {
	var randomstring = '';
	for (var idx = 0; idx < 20; idx++) {
	        randomstring += String.fromCharCode(Math.floor(Math.random() * 256));
	}

    	return randomString;
};
