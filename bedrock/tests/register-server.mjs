import { register } from 'node:module';
register('./server-loader.mjs', import.meta.url);
