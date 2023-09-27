import {
  log,
  json,
  JSONValueKind,
  Bytes,
  BigInt,
  TypedMap,
  JSONValue,
} from "@graphprotocol/graph-ts";
import {
  Context,
  FlowInitialized,
  Initialize,
  Initialized,
  MetaV1,
} from "../../generated/flowERC1155/flowERC1155";
import {
  FlowERC1155,
  EvaluableConfig,
  FlowConfig,
  ContextEntity,
  SignedContext,
  Evaluable,
  MetaContentV1,
} from "../../generated/schema";
import {
  RAIN_META_DOCUMENT_HEX,
  createAccount,
  getEventHex,
  getKeccak256FromBytes,
  getRainMetaV1,
  isHexadecimalString,
} from "../utils/utils";
import { CBORDecoder } from "@rainprotocol/assemblyscript-cbor";

export function handleContext(event: Context): void {
  let context_ = event.params.context;
  let context = new ContextEntity(event.transaction.hash.toHex());
  context.emitter = createAccount(event.params.sender.toHex()).id;
  context.contract = event.address.toHex();
  context.caller = createAccount(context_[0][0].toHex()).id;
  context.callingContext = context_[1];
  let signers = context_[2];
  for (let i = 0; i < signers.length; i++) {
    let signer = signers[i];
    let signedContext = new SignedContext(
      `${event.transaction.hash.toHex()}-${i}`
    );
    signedContext.signer = signer.toHex();
    signedContext.context = context_[i + 4];
    signedContext.contextEntity = context.id;
    signedContext.save();
  }
  let receipt = event.receipt;
  if (receipt != null) {
    log.info("receipt found: {}", [receipt.transactionHash.toHex()]);
  }
}

export function handleFlowInitialized(event: FlowInitialized): void {
  let flowERC1155 = FlowERC1155.load(event.address.toHex());
  if (flowERC1155 != null) {
    let evaluable = new Evaluable(flowERC1155.id);
    evaluable.store = event.params.evaluable.store;
    evaluable.interpreter = event.params.evaluable.interpreter;
    evaluable.expression = event.params.evaluable.expression;
    evaluable.save();
  }
}

export function handleInitialize(event: Initialize): void {
  let flowERC1155 = new FlowERC1155(event.address.toHex());
  flowERC1155.address = event.address;
  flowERC1155.sender = event.params.sender;
  flowERC1155.uri = event.params.config.uri;
  flowERC1155.save();

  let evaluableConfig = new EvaluableConfig(event.address.toHex());
  evaluableConfig.contract = flowERC1155.id;
  evaluableConfig.deployer = event.params.config.evaluableConfig.deployer;
  evaluableConfig.bytecode = event.params.config.evaluableConfig.bytecode;
  evaluableConfig.constants = event.params.config.evaluableConfig.constants;
  evaluableConfig.save();

  let flowConfigs = event.params.config.flowConfig;
  for (let index = 0; index < flowConfigs.length; index++) {
    let flowConfig = flowConfigs[index];
    let evaluableConfig = new FlowConfig(`${flowERC1155.id}-${index}`);
    evaluableConfig.contract = flowERC1155.id;
    evaluableConfig.deployer = flowConfig.deployer;
    evaluableConfig.bytecode = flowConfig.bytecode;
    evaluableConfig.constants = flowConfig.constants;
    evaluableConfig.save();
  }
}

export function handleInitialized(event: Initialized): void {
  let flowERC1155 = FlowERC1155.load(event.address.toHex());
  if (flowERC1155 != null) {
    flowERC1155.version = event.params.version;
    flowERC1155.save();
  }
}

export function handleMetaV1(event: MetaV1): void {
  const metaV1 = getRainMetaV1(event.params.meta);

  const subjectHex = getEventHex(event.params.subject.toHex());

  let flowERC1155 = FlowERC1155.load(event.address.toHex());
  if (flowERC1155 != null) {
    flowERC1155.meta = metaV1.id;
    flowERC1155.save();
  }

  // Converts the emitted target from Bytes to a Hexadecimal value
  let meta = event.params.meta.toHex();

  // Decode the meta only if incluse the RainMeta magic number.
  if (meta.includes(RAIN_META_DOCUMENT_HEX)) {
    meta = meta.replace(RAIN_META_DOCUMENT_HEX, "");

    const data = new CBORDecoder(stringToArrayBuffer(meta));
    const res = data.parse();

    const contentArr: ContentMeta[] = [];

    if (res.isSequence) {
      const dataString = res.toString();
      const jsonArr = json.fromString(dataString).toArray();
      for (let i = 0; i < jsonArr.length; i++) {
        const jsonValue = jsonArr[i];

        // if some value is not a JSON/Map, then is not following the RainMeta design.
        // So, return here to avoid assignation.
        if (jsonValue.kind != JSONValueKind.OBJECT) return;

        const jsonContent = jsonValue.toObject();

        // If some content is not valid, then skip it since is bad formed
        if (!ContentMeta.validate(jsonContent)) return;

        const content = new ContentMeta(jsonContent, metaV1.id);
        contentArr.push(content);
      }
    } else if (res.isObj) {
      const dataString = res.toString();
      const jsonObj = json.fromString(dataString).toObject();

      if (!ContentMeta.validate(jsonObj)) return;
      const content = new ContentMeta(jsonObj, metaV1.id);
      contentArr.push(content);
      //
    } else {
      // If the response is NOT a Sequence or an Object, then the meta have an
      // error or it's bad formed.
      // In this case, we skip to continue the decoding and assignation process.
      return;
    }

    for (let i = 0; i < contentArr.length; i++) {
      contentArr[i].generate();
    }
  } else {
    // The meta emitted does not include the RainMeta magic number, so does not
    // follow the RainMeta Desing
    return;
  }
}
function stringToArrayBuffer(meta: string): ArrayBuffer {
  throw new Error("Function not implemented.");
}

export class ContentMeta {
  rainMetaId: Bytes;
  payload: Bytes = Bytes.empty();
  magicNumber: BigInt = BigInt.zero();
  contentType: string = "";
  contentEncoding: string = "";
  contentLanguage: string = "";

  constructor(
    metaContentV1Object_: TypedMap<string, JSONValue>,
    rainMetaID_: Bytes
  ) {
    const payload = metaContentV1Object_.get("0");
    const magicNumber = metaContentV1Object_.get("1");
    const contentType = metaContentV1Object_.get("2");
    const contentEncoding = metaContentV1Object_.get("3");
    const contentLanguage = metaContentV1Object_.get("4");

    // RainMetaV1 ID
    this.rainMetaId = rainMetaID_;

    // Mandatories keys
    if (payload) {
      let auxPayload = payload.toString();
      if (auxPayload.startsWith("h'")) {
        auxPayload = auxPayload.replace("h'", "");
      }
      if (auxPayload.endsWith("'")) {
        auxPayload = auxPayload.replace("'", "");
      }

      this.payload = Bytes.fromHexString(auxPayload);
    }

    // if (payload) this.payload = payload.toString();
    if (magicNumber) this.magicNumber = magicNumber.toBigInt();

    // Keys optionals
    if (contentType) this.contentType = contentType.toString();
    if (contentEncoding) this.contentEncoding = contentEncoding.toString();
    if (contentLanguage) this.contentLanguage = contentLanguage.toString();
  }

  /**
   * Validate that the keys exist on the map
   */
  static validate(metaContentV1Object: TypedMap<string, JSONValue>): boolean {
    const payload = metaContentV1Object.get("0");
    const magicNumber = metaContentV1Object.get("1");
    const contentType = metaContentV1Object.get("2");
    const contentEncoding = metaContentV1Object.get("3");
    const contentLanguage = metaContentV1Object.get("4");

    // Only payload and magicNumber are mandatory on RainMetaV1
    // See: https://github.com/rainprotocol/specs/blob/main/metadata-v1.md
    if (payload && magicNumber) {
      if (
        payload.kind == JSONValueKind.STRING ||
        magicNumber.kind == JSONValueKind.NUMBER
      ) {
        // Check if payload is a valid Bytes (hexa)
        let auxPayload = payload.toString();
        if (auxPayload.startsWith("h'")) {
          auxPayload = auxPayload.replace("h'", "");
        }
        if (auxPayload.endsWith("'")) {
          auxPayload = auxPayload.replace("'", "");
        }

        // If the payload is not a valid bytes value
        if (!isHexadecimalString(auxPayload)) {
          return false;
        }

        // Check the type of optionals keys
        if (contentType) {
          if (contentType.kind != JSONValueKind.STRING) {
            return false;
          }
        }
        if (contentEncoding) {
          if (contentEncoding.kind != JSONValueKind.STRING) {
            return false;
          }
        }
        if (contentLanguage) {
          if (contentLanguage.kind != JSONValueKind.STRING) {
            return false;
          }
        }

        return true;
      }
    }

    return false;
  }

  private getContentId(): Bytes {
    // Values as Bytes
    const payloadB = this.payload;
    const magicNumberB = Bytes.fromHexString(this.magicNumber.toHex());
    const contentTypeB = Bytes.fromUTF8(this.contentType);
    const contentEncodingB = Bytes.fromUTF8(this.contentEncoding);
    const contentLanguageB = Bytes.fromUTF8(this.contentLanguage);

    // payload +  magicNumber + contentType + contentEncoding + contentLanguage
    const contentId = getKeccak256FromBytes(
      payloadB
        .concat(magicNumberB)
        .concat(contentTypeB)
        .concat(contentEncodingB)
        .concat(contentLanguageB)
    );

    return contentId;
  }

  /**
   * Create or generate a MetaContentV1 entity based on the current fields:
   *
   * - If the MetaContentV1 does not exist, create the MetaContentV1 entity and
   * made the relation to the rainMetaId.
   *
   * - If the MetaContentV1 does exist, add the relation to the rainMetaId.
   */
  generate(): MetaContentV1 {
    const contentId = this.getContentId();

    let metaContent = MetaContentV1.load(contentId);

    if (!metaContent) {
      metaContent = new MetaContentV1(contentId);

      metaContent.payload = this.payload;
      metaContent.magicNumber = this.magicNumber;
      metaContent.documents = [];

      if (this.contentType != "") metaContent.contentType = this.contentType;

      if (this.contentEncoding != "")
        metaContent.contentEncoding = this.contentEncoding;

      if (this.contentLanguage != "")
        metaContent.contentLanguage = this.contentLanguage;
    }

    const aux = metaContent.documents;
    if (!aux.includes(this.rainMetaId)) aux.push(this.rainMetaId);

    metaContent.documents = aux;

    metaContent.save();

    return metaContent;
  }
}
