import { Controller } from '@nestjs/common';
import { GrpcMethod } from '@nestjs/microservices';
import { logService } from '@invoice-hub/common';

interface GetInvoicesRequest {
  query: string;
}

@Controller()
export class AppController {
  @GrpcMethod('InvoiceService', 'GetInvoices')
  getInvoices(data: GetInvoicesRequest): { message: string } {
    logService('Invoice', 'GetInvoices');
    return { message: 'Invoice service is running!' };
  }
}
