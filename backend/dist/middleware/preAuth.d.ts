import { Request, Response, NextFunction } from 'express';
export interface PreAuthRequest extends Request {
    userId?: number;
}
export declare function verifyPreAuth(req: PreAuthRequest, res: Response, next: NextFunction): Response<any, Record<string, any>> | undefined;
//# sourceMappingURL=preAuth.d.ts.map