const express = require('express');
const os = require('os');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
    res.send({
        message: 'Hello World',
        hostname: os.hostname(),
        platform: os.platform(),
        arch: os.arch(),
        version: os.version(),
        uptime: os.uptime(),
        ip: req.ip
    });
});

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});

