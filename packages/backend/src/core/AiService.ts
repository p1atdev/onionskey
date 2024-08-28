/*
 * SPDX-FileCopyrightText: syuilo and misskey-project
 * SPDX-License-Identifier: AGPL-3.0-only
 */

import { fileURLToPath } from 'node:url';
import { dirname } from 'node:path';
import { Injectable } from '@nestjs/common';
import * as nsfw from 'nsfwjs';
import si from 'systeminformation';
import { Mutex } from 'async-mutex';
import { bindThis } from '@/decorators.js';

const _filename = fileURLToPath(import.meta.url);
const _dirname = dirname(_filename);

const REQUIRED_CPU_FLAGS = ['avx2', 'fma'];
let isSupportedCpu: undefined | boolean = undefined;

@Injectable()
export class AiService {
	private model: nsfw.NSFWJS;
	private modelLoadMutex: Mutex = new Mutex();

	constructor(
	) {
	}

	@bindThis
	public async detectSensitive(path: string): Promise<null> {
		return null;
	}

	@bindThis
	private async getCpuFlags(): Promise<string[]> {
		const str = await si.cpuFlags();
		return str.split(/\s+/);
	}
}
