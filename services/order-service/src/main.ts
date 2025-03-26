import { NestFactory } from '@nestjs/core';
import { Transport, MicroserviceOptions } from '@nestjs/microservices';
import { Logger } from '@nestjs/common';
import { PROTO_PATHS } from '@invoice-hub/common';

import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const port = 3003;
  
  const app = await NestFactory.createMicroservice<MicroserviceOptions>(
    AppModule,
    {
      transport: Transport.GRPC,
      options: {
        package: 'order',
        protoPath: PROTO_PATHS.ORDER,
        url: '0.0.0.0:' + port
      },
    },
  );

  await app.listen();
  logger.log(`Order service running on port ${port}`);
}

bootstrap().catch((error) => {
  new Logger('Bootstrap').error(`Error: ${error instanceof Error ? `${error.message}` : 'Unknown error'}`);
  process.exit(1);
});
