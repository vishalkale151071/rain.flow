import { Bytes, ethereum, crypto } from "@graphprotocol/graph-ts";
import { Transaction, Account, RainMetaV1 } from "../../generated/schema";

export const RAIN_META_DOCUMENT_HEX = "0xff0a89c674ee7874";

export function createTransaction(
  transation: ethereum.Transaction,
  block: ethereum.Block
): Transaction {
  let transation_ = Transaction.load(transation.hash.toHexString());
  if (transation_ == null) {
    transation_ = new Transaction(transation.hash.toHexString());
    transation_.blockNumber = block.number;
    transation_.timestamp = block.timestamp;
    transation_.from = transation.from;
    transation_.save();
  }
  return transation_;
}

export function createAccount(address: string): Account {
  let account = Account.load(address);
  if (account == null) {
    account = new Account(address);
    account.save();
  }
  return account;
}

export function getRainMetaV1(meta_: Bytes): RainMetaV1 {
  const metaV1_ID = getKeccak256FromBytes(meta_);

  let metaV1 = RainMetaV1.load(metaV1_ID);

  if (!metaV1) {
    metaV1 = new RainMetaV1(metaV1_ID);
    metaV1.metaBytes = meta_;
    metaV1.save();
  }

  return metaV1;
}

export function getKeccak256FromBytes(data_: Bytes): Bytes {
  return Bytes.fromByteArray(crypto.keccak256(Bytes.fromByteArray(data_)));
}

/**
 * From a given hexadecimal string, check if it's have an even length
 */
export function getEventHex(value_: string): string {
  if (value_.length % 2) {
    value_ = value_.slice(0, 2) + "0" + value_.slice(2);
  }

  return value_;
}

export function isHexadecimalString(str: string): boolean {
  // Check if string is empty
  if (str.length == 0) {
    return false;
  }

  // Check if each character is a valid hexadecimal character
  for (let i = 0; i < str.length; i++) {
    let charCode = str.charCodeAt(i);
    if (
      !(
        (charCode >= 48 && charCode <= 57) || // 0-9
        (charCode >= 65 && charCode <= 70) || // A-F
        (charCode >= 97 && charCode <= 102)
      )
    ) {
      // a-f
      return false;
    }
  }

  return true;
}
