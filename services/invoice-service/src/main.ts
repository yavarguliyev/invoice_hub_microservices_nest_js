import { NestFactory } from '@nestjs/core';
import { Transport, MicroserviceOptions } from '@nestjs/microservices';
import { Logger } from '@nestjs/common';
import { PROTO_PATHS } from '@invoice-hub/common';
import { ConfigService } from '@nestjs/config';

import { AppModule } from './app.module';

async function bootstrap () {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);
  const port = configService.get<number>('PORT', 3002);

  await app.close();
  
  const microservice = await NestFactory.createMicroservice<MicroserviceOptions>(
    AppModule,
    {
      transport: Transport.GRPC,
      options: {
        package: 'invoice',
        protoPath: PROTO_PATHS.INVOICE,
        url: '0.0.0.0:' + port
      },
    },
  );

  await microservice.listen();
  logger.log(`Invoice service running on port ${port}`);
}

bootstrap().catch((error) => {
  new Logger('Bootstrap').error(`Error: ${error instanceof Error ? `${error.message}` : 'Unknown error'}`);
  process.exit(1);
});
