import { Controller } from '@nestjs/common';
import { GrpcMethod } from '@nestjs/microservices';
import { logService } from '@invoice-hub/common';

@Controller()
export class AppController {
  @GrpcMethod('InvoiceService', 'GetInvoices')
  getInvoices (): { message: string } {
    logService('Invoice', 'GetInvoices');
    return { message: 'Invoice service is running!' };
  }
}
