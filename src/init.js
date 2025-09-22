const mongoose = require('mongoose');
mongoose.connect('mongodb://localhost/devops', { useNewUrlParser: true, useUnifiedTopology: true });

const Dev = mongoose.model('Dev', { name: String });

Dev.insertMany([{ name: 'Team A' }, { name: 'Team B' }, { name: 'Team C' }])
  .then(() => {
    console.log('Database seeded successfully');
    process.exit();
  })
  .catch(err => {
    console.error(err);
    process.exit(1);
  });