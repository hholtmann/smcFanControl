/*
 * Apple System Management Control (SMC) Tool 
 * Copyright (C) 2006 devnull 
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <IOKit/IOKitLib.h>

#include "smc.h"

io_connect_t conn;

UInt32 _strtoul(char *str, int size, int base)
{
    UInt32 total = 0;
    int i;

    for (i = 0; i < size; i++)
    {
        if (base == 16)
            total += str[i] << (size - 1 - i) * 8;
        else
           total += (unsigned char) (str[i] << (size - 1 - i) * 8);
    }
    return total;
}

void _ultostr(char *str, UInt32 val)
{
    str[0] = '\0';
    sprintf(str, "%c%c%c%c", 
            (unsigned int) val >> 24,
            (unsigned int) val >> 16,
            (unsigned int) val >> 8,
            (unsigned int) val);
}

float _strtof(char *str, int size, int e)
{
    float total = 0;
    int i;

    for (i = 0; i < size; i++)
    {
        if (i == (size - 1))
           total += (str[i] & 0xff) >> e;
        else
           total += str[i] << (size - 1 - i) * (8 - e);
    }

    return total;
}

void smc_init(){
	SMCOpen(&conn);
}

void smc_close(){
	SMCClose(conn);
}
void printFPE2(SMCVal_t val)
{
    /* FIXME: This decode is incomplete, last 2 bits are dropped */

    printf("%.0f ", _strtof(val.bytes, val.dataSize, 2));
}

void printUInt(SMCVal_t val)
{
    printf("%u ", (unsigned int) _strtoul(val.bytes, val.dataSize, 10));
}

void printBytesHex(SMCVal_t val)
{
    int i;

    printf("(bytes");
    for (i = 0; i < val.dataSize; i++)
        printf(" %02x", (unsigned char) val.bytes[i]);
    printf(")\n");
}

void printVal(SMCVal_t val)
{
    printf("  %-4s  [%-4s]  ", val.key, val.dataType);
    if (val.dataSize > 0)
    {
        if ((strcmp(val.dataType, DATATYPE_UINT8) == 0) ||
            (strcmp(val.dataType, DATATYPE_UINT16) == 0) ||
            (strcmp(val.dataType, DATATYPE_UINT32) == 0))
            printUInt(val);
        else if (strcmp(val.dataType, DATATYPE_FPE2) == 0)
            printFPE2(val);

        printBytesHex(val);
    }
    else
    {
            printf("no data\n");
    }
}

kern_return_t SMCOpen(io_connect_t *conn)
{
    kern_return_t result;
    mach_port_t   masterPort;
    io_iterator_t iterator;
    io_object_t   device;

	IOMasterPort(MACH_PORT_NULL, &masterPort);

    CFMutableDictionaryRef matchingDictionary = IOServiceMatching("AppleSMC");
    result = IOServiceGetMatchingServices(masterPort, matchingDictionary, &iterator);
    if (result != kIOReturnSuccess)
    {
        printf("Error: IOServiceGetMatchingServices() = %08x\n", result);
        return 1;
    }

    device = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    if (device == 0)
    {
        printf("Error: no SMC found\n");
        return 1;
    }

    result = IOServiceOpen(device, mach_task_self(), 0, conn);
    IOObjectRelease(device);
    if (result != kIOReturnSuccess)
    {
        printf("Error: IOServiceOpen() = %08x\n", result);
        return 1;
    }

    return kIOReturnSuccess;
}

kern_return_t SMCClose(io_connect_t conn)
{
    return IOServiceClose(conn);
}


kern_return_t SMCCall(int index, SMCKeyData_t *inputStructure, SMCKeyData_t *outputStructure)
{
    size_t   structureInputSize;
    size_t   structureOutputSize;

    structureInputSize = sizeof(SMCKeyData_t);
    structureOutputSize = sizeof(SMCKeyData_t);
/*
    return IOConnectMethodStructureIStructureO(
               conn,
               index,
               structureInputSize,
               &structureOutputSize,
               inputStructure,
               outputStructure
             );
*/ 
    return IOConnectCallStructMethod(conn, index, inputStructure, structureInputSize, outputStructure, &structureOutputSize);
}

kern_return_t SMCCall2(int index, SMCKeyData_t *inputStructure, SMCKeyData_t *outputStructure,io_connect_t conn)
{
    size_t   structureInputSize;
    size_t   structureOutputSize;
    structureInputSize = sizeof(SMCKeyData_t);
    structureOutputSize = sizeof(SMCKeyData_t);

   /* return IOConnectMethodStructureIStructureO(
               conn,
               index,
               structureInputSize,
               &structureOutputSize,
               inputStructure,
               outputStructure
             );
    */
    return IOConnectCallStructMethod(conn, index, inputStructure, structureInputSize, outputStructure, &structureOutputSize);

}

kern_return_t SMCReadKey2(UInt32Char_t key, SMCVal_t *val,io_connect_t conn)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));

    inputStructure.key = _strtoul(key, 4, 16);
    sprintf(val->key, key);
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;    

    result = SMCCall2(KERNEL_INDEX_SMC, &inputStructure, &outputStructure,conn);
    if (result != kIOReturnSuccess)
        return result;

    val->dataSize = outputStructure.keyInfo.dataSize;
    _ultostr(val->dataType, outputStructure.keyInfo.dataType);
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = SMC_CMD_READ_BYTES;

    result = SMCCall2(KERNEL_INDEX_SMC, &inputStructure, &outputStructure,conn);
    if (result != kIOReturnSuccess)
	return result;

    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));

    return kIOReturnSuccess;
}
kern_return_t SMCReadKey(UInt32Char_t key, SMCVal_t *val)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));
    memset(val, 0, sizeof(SMCVal_t));

    inputStructure.key = _strtoul(key, 4, 16);
    sprintf(val->key, key);
    inputStructure.data8 = SMC_CMD_READ_KEYINFO;    

    result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    val->dataSize = outputStructure.keyInfo.dataSize;
    _ultostr(val->dataType, outputStructure.keyInfo.dataType);
    inputStructure.keyInfo.dataSize = val->dataSize;
    inputStructure.data8 = SMC_CMD_READ_BYTES;

    result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
    if (result != kIOReturnSuccess)
        return result;

    memcpy(val->bytes, outputStructure.bytes, sizeof(outputStructure.bytes));

    return kIOReturnSuccess;
}


kern_return_t SMCWriteKey(SMCVal_t writeVal)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    SMCVal_t      readVal;

    result = SMCReadKey(writeVal.key, &readVal);
    if (result != kIOReturnSuccess) 
        return result;

    if (readVal.dataSize != writeVal.dataSize)
        return kIOReturnError;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));

    inputStructure.key = _strtoul(writeVal.key, 4, 16);
    inputStructure.data8 = SMC_CMD_WRITE_BYTES;    
    inputStructure.keyInfo.dataSize = writeVal.dataSize;
    memcpy(inputStructure.bytes, writeVal.bytes, sizeof(writeVal.bytes));

    result = SMCCall2(KERNEL_INDEX_SMC, &inputStructure, &outputStructure,conn);
    if (result != kIOReturnSuccess)
        return result;
 
    return kIOReturnSuccess;
}

kern_return_t SMCWriteKey2(SMCVal_t writeVal,io_connect_t conn)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    SMCVal_t      readVal;

    result = SMCReadKey2(writeVal.key, &readVal,conn);
    if (result != kIOReturnSuccess) 
        return result;

    if (readVal.dataSize != writeVal.dataSize)
        return kIOReturnError;

    memset(&inputStructure, 0, sizeof(SMCKeyData_t));
    memset(&outputStructure, 0, sizeof(SMCKeyData_t));

    inputStructure.key = _strtoul(writeVal.key, 4, 16);
    inputStructure.data8 = SMC_CMD_WRITE_BYTES;    
    inputStructure.keyInfo.dataSize = writeVal.dataSize;
    memcpy(inputStructure.bytes, writeVal.bytes, sizeof(writeVal.bytes));
    result = SMCCall2(KERNEL_INDEX_SMC, &inputStructure, &outputStructure,conn);

    if (result != kIOReturnSuccess)
        return result;
    return kIOReturnSuccess;
}


UInt32 SMCReadIndexCount(void)
{
    SMCVal_t val;

    SMCReadKey("#KEY", &val);
    return _strtoul(val.bytes, val.dataSize, 10);
}

kern_return_t SMCPrintAll(void)
{
    kern_return_t result;
    SMCKeyData_t  inputStructure;
    SMCKeyData_t  outputStructure;

    int           totalKeys, i;
    UInt32Char_t  key;
    SMCVal_t      val;

    totalKeys = SMCReadIndexCount();
    for (i = 0; i < totalKeys; i++)
    {
        memset(&inputStructure, 0, sizeof(SMCKeyData_t));
        memset(&outputStructure, 0, sizeof(SMCKeyData_t));
        memset(&val, 0, sizeof(SMCVal_t));

        inputStructure.data8 = SMC_CMD_READ_INDEX;
        inputStructure.data32 = i;

        result = SMCCall(KERNEL_INDEX_SMC, &inputStructure, &outputStructure);
        if (result != kIOReturnSuccess)
            continue;

        _ultostr(key, outputStructure.key); 

		SMCReadKey(key, &val);
        printVal(val);
    }

    return kIOReturnSuccess;
}

kern_return_t SMCPrintFans(void)
{
    kern_return_t result;
    SMCVal_t      val;
    UInt32Char_t  key;
    int           totalFans, i;

    result = SMCReadKey("FNum", &val);
    if (result != kIOReturnSuccess)
        return kIOReturnError;

    totalFans = _strtoul(val.bytes, val.dataSize, 10); 
    printf("Total fans in system: %d\n", totalFans);

    for (i = 0; i < totalFans; i++)
    {
        printf("\nFan #%d:\n", i);
        sprintf(key, "F%dAc", i); 
        SMCReadKey(key, &val); 
        printf("    Actual speed : %.0f\n", _strtof(val.bytes, val.dataSize, 2));
        sprintf(key, "F%dMn", i);   
        SMCReadKey(key, &val);
        printf("    Minimum speed: %.0f\n", _strtof(val.bytes, val.dataSize, 2));
        sprintf(key, "F%dMx", i);   
        SMCReadKey(key, &val);
        printf("    Maximum speed: %.0f\n", _strtof(val.bytes, val.dataSize, 2));
        sprintf(key, "F%dSf", i);   
        SMCReadKey(key, &val);
        printf("    Safe speed   : %.0f\n", _strtof(val.bytes, val.dataSize, 2));
        sprintf(key, "F%dTg", i);   
        SMCReadKey(key, &val);
        printf("    Target speed : %.0f\n", _strtof(val.bytes, val.dataSize, 2));
        SMCReadKey("FS! ", &val);
        if ((_strtoul(val.bytes, 2, 16) & (1 << i)) == 0)
            printf("    Mode         : auto\n"); 
        else
            printf("    Mode         : forced\n");
    }

    return kIOReturnSuccess;
}

void usage(char* prog)
{
        printf("Apple System Management Control (SMC) tool %s\n", VERSION);
        printf("Usage:\n");
        printf("%s [options]\n", prog);
        printf("    -f         : fan info decoded\n");
        printf("    -h         : help\n");
        printf("    -k <key>   : key to manipulate\n");
        printf("    -l         : list all keys and values\n");
        printf("    -r         : read the value of a key\n");
        printf("    -w <value> : write the specified value to a key\n");
        printf("    -v         : version\n");
        printf("\n");
}

kern_return_t SMCWriteSimple(UInt32Char_t key,char *wvalue,io_connect_t conn)
{
	    kern_return_t result;
		SMCVal_t   val;
		int i;
		char c[3];
		for (i = 0; i < strlen(wvalue); i++)
		{
                    sprintf(c, "%c%c", wvalue[i * 2], wvalue[(i * 2) + 1]);
                    val.bytes[i] = (int) strtol(c, NULL, 16);
		}
		val.dataSize = i / 2;
		sprintf(val.key, key);
		result = SMCWriteKey2(val,conn);
		   if (result != kIOReturnSuccess)
                printf("Error: SMCWriteKey() = %08x\n", result);
	

		return result;
}


#ifdef CMD_TOOL
int main(int argc, char *argv[])
{
    int c;
    extern char   *optarg;

    kern_return_t result;
    int           op = OP_NONE;
    UInt32Char_t  key = "\0";
    SMCVal_t      val;

    while ((c = getopt(argc, argv, "fhk:lrw:v")) != -1)
    {
        switch(c)
        {
        case 'f':
            op = OP_READ_FAN;
            break;
        case 'k':
			strncpy(key, optarg, sizeof(key));   //fix for buffer overflow
            break;
        case 'l':
            op = OP_LIST;
            break;
        case 'r':
            op = OP_READ;
            break;
        case 'v':
            printf("%s\n", VERSION);
            return 0;
            break;
        case 'w':
            op = OP_WRITE;
            {
                int i;
                char c[3];
                for (i = 0; i < strlen(optarg); i++)
                {
                    sprintf(c, "%c%c", optarg[i * 2], optarg[(i * 2) + 1]);
                    val.bytes[i] = (int) strtol(c, NULL, 16);
                }
                val.dataSize = i / 2;
                if ((val.dataSize * 2) != strlen(optarg))
                {
                    printf("Error: value is not valid\n");
                    return 1;
                }
            }
            break;
        case 'h':
        case '?':
            op = OP_NONE;
            break;
        }
    }

    if (op == OP_NONE)
    {
       usage(argv[0]);
       return 1;
    }

    SMCOpen(&conn);

    switch(op)
    {
    case OP_LIST:
        result = SMCPrintAll();
            if (result != kIOReturnSuccess)
                printf("Error: SMCPrintAll() = %08x\n", result);
        break;
    case OP_READ:
        if (strlen(key) > 0)
        {
            result = SMCReadKey(key, &val);
            if (result != kIOReturnSuccess)
                printf("Error: SMCReadKey() = %08x\n", result);
            else
                printVal(val);
        }
        else
        {
            printf("Error: specify a key to read\n");
        }
        break;
    case OP_READ_FAN:
        result = SMCPrintFans();
        if (result != kIOReturnSuccess)
            printf("Error: SMCPrintFans() = %08x\n", result);
        break;
    case OP_WRITE:
        if (strlen(key) > 0)
        {
            sprintf(val.key, key);
            result = SMCWriteKey(val);
            if (result != kIOReturnSuccess)
                printf("Error: SMCWriteKey() = %08x\n", result);
        }
        else
        {
            printf("Error: specify a key to write\n");
        }
        break;
    }

    SMCClose(conn);
    return 0;;
}
#endif

