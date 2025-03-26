import { Module } from '@nestjs/common';
import { ClientsModule, Transport } from '@nestjs/microservices';
import { PROTO_PATHS } from '@invoice-hub/common';

import { AppController } from './app.controller';

@Module({
  imports: [
    ClientsModule.register([
      {
        name: 'AUTH_SERVICE',
        transport: Transport.GRPC,
        options: {
          package: 'auth',
          protoPath: PROTO_PATHS.AUTH,
          url: `${process.env.AUTH_SERVICE_HOST || 'localhost'}:${parseInt(process.env.AUTH_SERVICE_PORT || '3001', 10)}`,
        },
      },
      {
        name: 'INVOICE_SERVICE',
        transport: Transport.GRPC,
        options: {
          package: 'invoice',
          protoPath: PROTO_PATHS.INVOICE,
          url: `${process.env.INVOICE_SERVICE_HOST || 'localhost'}:${parseInt(process.env.INVOICE_SERVICE_PORT || '3002', 10)}`,
        },
      },
      {
        name: 'ORDER_SERVICE',
        transport: Transport.GRPC,
        options: {
          package: 'order',
          protoPath: PROTO_PATHS.ORDER,
          url: `${process.env.ORDER_SERVICE_HOST || 'localhost'}:${parseInt(process.env.ORDER_SERVICE_PORT || '3003', 10)}`,
        },
      },
    ]),
  ],
  controllers: [AppController],
  providers: []
})
export class AppModule {}
