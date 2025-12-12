import express from 'express';
import cors from 'cors';

import logger from './middleware/logger.js';
import errorHandeler from './middleware/error.js';
import notfound from './middleware/notfound.js';

import bash from './routes/bash.js';

const app = express();
const PORT = 8000;

app.use(express.json()); 
app.use(express.urlencoded({ extended: true }));

app.use(cors({
    origin: "http://localhost:5173",
    credentials: true
}));

app.use(logger);

//routes
app.use("/bash", bash);

app.use(notfound);
app.use(errorHandeler);


app.listen(PORT, () => console.log(`Server running on: http://localhost:${PORT}/`));