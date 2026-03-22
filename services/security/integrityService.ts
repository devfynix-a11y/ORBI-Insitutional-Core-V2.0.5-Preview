import crypto from 'crypto';

export class IntegrityService {

    static hash(data: any) {
        return crypto
            .createHash('sha256')
            .update(JSON.stringify(data))
            .digest('hex');
    }

    static verify(data: any, hash: string) {
        return this.hash(data) === hash;
    }
}
