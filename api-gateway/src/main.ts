import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

import { AppModule } from './app.module';

async function bootstrap () {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  const logger = new Logger('Bootstrap');
  const port = configService.get<number>('PORT', 3000);
  
  await app.listen(port, () => logger.log(`Api gateway running on port ${port}`));
}

bootstrap().catch((error) => {
  new Logger('Bootstrap').error(`Error: ${error instanceof Error ? `${error.message}` : 'Unknown error'}`);
  process.exit(1);
});
