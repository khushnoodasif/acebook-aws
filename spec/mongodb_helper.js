var mongoose = require('mongoose');

const mongoDbUrl = process.env.MONGODB_URL || 'mongodb://localhost/acebook';

beforeAll(function(done) {
  mongoose.connect(mongoDbUrl, {
    useNewUrlParser: true,
    useUnifiedTopology: true
  });

  var db = mongoose.connection;
  db.on('error', console.error.bind(console, 'MongoDB connection error:'));
  db.on('open', function() {
    done();
  });
});

afterAll(function(done) {
  mongoose.connection.close(true, function() {
    done();
  });
});
