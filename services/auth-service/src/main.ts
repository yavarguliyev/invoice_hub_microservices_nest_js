import { NestFactory } from '@nestjs/core';
import { Transport, MicroserviceOptions } from '@nestjs/microservices';
import { Logger } from '@nestjs/common';
import { PROTO_PATHS } from '@invoice-hub/common';

import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const port = 3001;
  
  const app = await NestFactory.createMicroservice<MicroserviceOptions>(
    AppModule,
    {
      transport: Transport.GRPC,
      options: {
        package: 'auth',
        protoPath: PROTO_PATHS.AUTH,
        url: '0.0.0.0:' + port
      },
    },
  );

  await app.listen();
  logger.log(`Auth service running on port ${port}`);
}

bootstrap().catch((error) => {
  new Logger('Bootstrap').error(`Error: ${error instanceof Error ? `${error.message}` : 'Unknown error'}`);
  process.exit(1);
});
