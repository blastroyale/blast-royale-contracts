import { task } from 'hardhat/config'
import { deployAll } from './deployAll'
import { verifyAll } from './verifyAll'

task('verifyAll', 'verify all contracts', verifyAll)

task('deployAll', 'verify all contracts', deployAll)
