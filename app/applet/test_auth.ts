import { generateAuthenticationOptions } from "@simplewebauthn/server";

async function test() {
    const options = await generateAuthenticationOptions({
        rpID: "example.com",
        allowCredentials: [{
            id: "W_N0jHJY9NYyf4tGe2kOvYl5BGpV7ZZW2b6hl_lqqAo" as any,
            type: "public-key"
        }]
    });
    console.log(options.allowCredentials);
}

test();
