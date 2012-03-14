//
//  MJPEGClient.m
//  MJPEGSocketDesktop
//
//  Created by Hao Hu on 29.07.11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MJPEGClient.h"
#import "NSString+Utils.h"


@implementation MJPEGClient
@synthesize clientId = _clientId;
@synthesize userName = _userName;
@synthesize password = _password;
@synthesize host = _host;
@synthesize path = _path;
@synthesize port = _port;
@synthesize isStopped = _isStopped;
@synthesize query = _query;


//**************************MJPEG Client constants list********************************
NSString* const HTTP_GET_PATTERN = @"GET %@ HTTP/1.1\r\n";
NSString * const HEADER_USER_AGENT = @"User-Agent: iPhone MJPEG Client 1.0\r\n";
NSString * const HEADER_CONNECTION = @"Connection: keep-alive\r\n";
NSString * const HEADER_HOST = @"Host: %@\r\n";
NSString * const HEADER_AUTH= @"Authorization: %@\r\n";

NSString * const HEADER_CONTENT_TYPE= @"content-type:";
NSString * const HEADER_CONTENT_LENGTH = @"content-length";

const UInt8 CRLF_CRLF[] = {0X0d,0x0a,0X0d,0x0a};
const UInt8 CRLF_CRLF_CRLF[] = {0X0d,0x0a,0X0d,0x0a,0X0d,0x0a};

const UInt8 CR_LF[] = {0X0d,0x0a};
const UInt8 SOI[] = {0xff,0xd8};

//**************************************************************************************

#pragma mark - Debug Helper
-(void) dumpData:(NSData*) data
{
    const UInt8* tmpData = data.bytes;
    NSUInteger length = [data length];
    int c = 0;
    for (int i = 0; i< length; i++) {
        printf("%02X ", tmpData[i]);
        c++;
        if (c > 20)
        {
            c = 0;
            printf("\n");
        }
    }
     
    printf("\n");
}

-(BOOL) isValidImage:(NSData*) imageData
{
    const UInt8* tmpData = [imageData bytes];
    NSUInteger length = [imageData length];
    UInt8 b1 =tmpData[0];
    UInt8 b2 =tmpData[1];
    UInt8 blast =tmpData[length-1];
    UInt8 blast2 =tmpData[length-2];
    NSString * output= [NSString stringWithFormat:@"1st %x, 2nd %x, last %x, last2 %x",b1,b2,blast,blast2];
    NSLog(@"%@",output);
    
    if (tmpData[0] == 0xff && tmpData[1] == 0xd8 && tmpData[length-1] == 0xd9 && tmpData[length-2] == 0xff)
    {
        return YES;
    }
    else
    {
        return NO;
    }
}



-(void) doGet
{
    //1. Write the first GET Line
    NSString* getLine = nil;
    if (self.query)
    {
        NSString *strFullPath = [NSString stringWithFormat:@"%@?%@",self.path,self.query];
        getLine = [[NSString alloc] initWithFormat:HTTP_GET_PATTERN, strFullPath];
    }
    else
    {
        getLine = [[NSString alloc] initWithFormat:HTTP_GET_PATTERN, _path];
    }
    
    [socket writeData:[getLine dataUsingEncoding:NSUTF8StringEncoding] withTimeout:_timeout tag:WRITE_TAG_GET];
    [getLine release];
    //2. Write Headers one by one
    NSString *hostHeader = [[NSString alloc] initWithFormat:HEADER_HOST,_host];
    NSString *authHeader = nil;
    
    if (_userName != nil && _password != nil)
    {
        NSString *authString = [[NSString alloc] initWithFormat:@"%@:%@",_userName,_password];
        NSString *authedString = [Base64 encodePlaintText:authString];
        [authString release];
        NSString *value = [[NSString alloc] initWithFormat:@"Basic %@",authedString];
        authHeader = [[NSString alloc] initWithFormat:HEADER_AUTH,value];
        [value release];
    }
    
    NSString *allHeaders = nil;
    if (authHeader)
    {
        allHeaders = [[NSString alloc] initWithFormat:@"%@%@%@%@\r\n\r\n", hostHeader,HEADER_USER_AGENT,authHeader,HEADER_CONNECTION];
    }
    else
    {
        allHeaders = [[NSString alloc] initWithFormat:@"%@%@%@\r\n\r\n", hostHeader,HEADER_USER_AGENT,HEADER_CONNECTION];
    }
    
    [socket writeData:[allHeaders dataUsingEncoding:NSUTF8StringEncoding] withTimeout:_timeout tag:WRITE_TAG_HEADERS];
    [authHeader release];
    [hostHeader release];
    [allHeaders release];
}

- (id) initWithURL:(NSString *)url delegate:(id<MJPEGClientDelegate>)delegate timeout:(NSTimeInterval)timeout
{
    if ((self = [super init]))
    {
        _timeout = timeout;
        _delegate = delegate;
        NSURL *nsUrl = [[NSURL alloc] initWithString:url];
        self.host = [nsUrl host] ;
        self.path = [nsUrl path] ;
        self.query = [nsUrl query];
        
        NSNumber * httpPort = [nsUrl port];
        _port = [httpPort unsignedIntValue];
        [nsUrl release];
        
        if (self.port <= 0)
            self.port = 80;
        
        imgBuffer = [[NSMutableData alloc] initWithLength:(BUFFER_SIZE * 10)];
    }
    return self;
}


- (void) start
{
    NSError *error = nil;
    if (socket)
    {
        [self stop];
    }
    
    socket = [[AsyncSocket alloc] initWithDelegate:self];
    
    if ( ![socket connectToHost:_host onPort:_port withTimeout:_timeout error:&error])
    {
        NSLog(@"Error to connect. The reason is %@", [error localizedDescription]);
        [_delegate mjpegClient:self didReceiveError:error];
        return;
    }
    
}




- (void) stop
{
    if (socket)
    {
        if ([socket isConnected])
            [socket disconnect];
    }
}



- (void)dealloc
{
    [self.userName release];
    [self.password release];
    [self.query release];
    [self.host release];
    [self.path release];
    [imgBuffer release];
    [super dealloc];
}

/*
 Find the "target" data inside the data, and return the position of "target" data.
 */
-(NSInteger) findPos:(const UInt8*) target forLength:(NSUInteger) length withData:(NSData*) data
{
   // NSString* temp = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
   // NSLog(@"%@",temp);
    
    const UInt8 *buf = [data bytes];
    int index = 0;
    for (int i = 0; i < [data length]; i++) {
        if (buf[i] == target[index])
        {
            index++;
            if (index > length-1)
                return (i);
        }
        else
        {
            index = 0;
        }
    }
    return  -1;
}

/*
 Get the length of all Headers, in fact, it tries to get the position of 
 CRLF,CRLF
 */
-(NSInteger) findHeaderLength:(NSData*) data
{
    return [self findPos:CRLF_CRLF forLength:4 withData:data];
}

/*
 Get the position of SOI
 Hao: Refactor it later.
 */
- (NSInteger) findSOIPos:(NSData*) data
{
    
    return  [self findPos:SOI forLength:2 withData:data];
}

/*
 Get the HTTP Headers from the response.
 */
-(NSDictionary*) getHeaders:(NSData*) data
{
    NSString *strHeaders = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
   
    NSArray* headers = [strHeaders componentsSeparatedByString:CRLF];
    [strHeaders release];
    
    if ([headers count] <=0 )
        return nil;
    NSMutableDictionary *resultHeaders = [[[NSMutableDictionary alloc] init] autorelease];
    for (NSString *header in headers)
    {
        //NSLog(@"Header: %@",header);
        NSArray* headerComp = [header componentsSeparatedByString:@":"];
        if ([headerComp count] == 2)
        {
            NSString* name = [[[headerComp objectAtIndex:0] trim] lowercaseString];
            NSString* value = [[headerComp objectAtIndex:1] trim];
            [resultHeaders setObject:value forKey:name];
        }
    }
    
    return resultHeaders;
}

/**
 Without the exception, the result should contain THREE elements.
 0. HTTPVersion
 1. Response code
 2. Response message
 */
-(NSArray*) getStatusLine:(NSData*) data
{
    NSInteger pos = [self findPos:CR_LF forLength:2 withData:data];
    NSData * firstLineData = [data subdataWithRange:NSMakeRange(0, pos)];
    NSString * strLine = [[NSString alloc] initWithData:firstLineData encoding:NSUTF8StringEncoding];
    NSArray *parts = [strLine componentsSeparatedByString:@" "];
    NSRange range = [strLine rangeOfString:@"HTTP/1." options:NSCaseInsensitiveSearch];
    [strLine release];
    if ([parts count] != 3 || range.location == NSNotFound)
        return nil;
    return parts;
}


/*
 Get the Content-Length header from the response.
 */
- (NSUInteger) getContentLength:(NSData*) data
{
    NSString *strContentLength = [[self getHeaders:data] objectForKey:HEADER_CONTENT_LENGTH];
    if (strContentLength)
    {
        return [strContentLength intValue];
    }
    else
        return 0;
}



#pragma mark -
//********************************asyncsocket callback delegate********************************
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    switch (tag) {
        case WRITE_TAG_GET:
            //NSLog(@"GET Line written.");
            break;
        case WRITE_TAG_HEADERS:
            //NSLog(@"Headers written.");
            //As all HTTP headers are written successfully, ok, read the response now.
            [imgBuffer setLength:0];
            [sock readDataToLength:BUFFER_SIZE_FOR_HEADER withTimeout:_timeout tag:READ_TAG_HTTP_HEADERS];
            break;
    }
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //NSLog(@"Read!");
    
    if (READ_TAG_HTTP_HEADERS == tag )
    {
        [imgBuffer appendData:data];
        NSInteger pos;
        pos = [self findHeaderLength:imgBuffer];
        //NSLog(@"The header line pos is %d",pos);
        if (pos != -1)
        {            
            NSData *headersData = [imgBuffer subdataWithRange:NSMakeRange(0, pos)];
            NSArray* statusLine = [self getStatusLine:headersData];
            if (statusLine)
            {
                int statusCode = [[statusLine objectAtIndex:1] intValue];
                if (statusCode == 401)
                {
                    //Auth error.
                    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                    [userInfo setObject:@"401 Unauthorized" forKey:NSLocalizedDescriptionKey];
                    [userInfo setObject:@"Input correct combination of Username and password." forKey:NSLocalizedRecoverySuggestionErrorKey];
                    NSError *error = [[[NSError alloc] initWithDomain:NSCocoaErrorDomain code:ERROR_AUTH userInfo:userInfo] autorelease];
                    [userInfo release];
                    if (_delegate)
                        [_delegate mjpegClient:self didReceiveError:error];
                    [self stop];
                    return;
                }
            }
            
            NSRange range = NSMakeRange(pos, [imgBuffer length] - pos);
            NSData *tmpData = [imgBuffer subdataWithRange:range];
            //Clear the imgbuffer, prepair for receiving Image data.
            [imgBuffer setLength:0];
            [imgBuffer appendData:tmpData];
            //Let's read the position of SOI
            [sock readDataToLength:BUFFER_SIZE withTimeout:_timeout tag:READ_TAG_SOI];
            
        }
        else
        {
            if ([imgBuffer length] > MAX_FRAME_SIZE)
            {
                //OK, we cannot get the header, since we read sooooo many bytes.
                //Error occurs.Callback the delegate.
                NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                [userInfo setObject:@"Unknown Error!" forKey:NSLocalizedDescriptionKey];
                NSError *error = [[[NSError alloc] initWithDomain:NSCocoaErrorDomain code:ERROR_UNKNOWN userInfo:userInfo] autorelease];
                [userInfo release];
                if (_delegate)
                    [_delegate mjpegClient:self didReceiveError:error];
                [self stop];
                return;
            }
            [sock readDataToLength:BUFFER_SIZE_FOR_HEADER withTimeout:_timeout tag:READ_TAG_HTTP_HEADERS];
        }
        
    }
    else if (READ_TAG_SOI == tag)
    {
        [imgBuffer appendData:data];
        NSInteger posOfSOI = [self findSOIPos:imgBuffer] - 1;
        NSData *soiHeaderData = [imgBuffer subdataWithRange:NSMakeRange(0, posOfSOI)];
        NSUInteger lengthOfImage = [self getContentLength:soiHeaderData];
        NSUInteger lengthToread = lengthOfImage - ([imgBuffer length] - posOfSOI);
        NSData *tmpData = [imgBuffer subdataWithRange:NSMakeRange(posOfSOI, ([imgBuffer length] - posOfSOI))];
        [imgBuffer setLength:0];
        [imgBuffer appendData:tmpData];
        
        [sock readDataToLength:lengthToread withTimeout:_timeout tag:READ_TAG_IMAGE];
    }
    
    else if (READ_TAG_IMAGE == tag)
    {
        [imgBuffer appendData:data];
        //NSUInteger lengthOfData = [imgBuffer length];
        //NSLog(@"The image data length is %lu.",lengthOfData);
        
        if (_delegate)
        {
            NSData *imgDataToGen = [NSData dataWithData:imgBuffer];
            UIImage *img = [[[UIImage alloc] initWithData:imgDataToGen] autorelease];
            [_delegate mjpegClient:self didReceiveImage:img];
        } 
        [imgBuffer setLength:0];      
        //Read the next picture.
        [sock readDataToLength:BUFFER_SIZE withTimeout:_timeout tag:READ_TAG_SOI];
    }
    
}

- (NSTimeInterval)onSocket:(AsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length
{
    NSLog(@"Timeout occurs");
    return  _timeout;
}


- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Connected to %@ on port %d", host, port);
    //After successfully connected to the host, send the GET request.
    _isStopped = NO;
    [self doGet];
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    [sock release];
    socket = nil;
    _isStopped = YES;
}

//************************************************************************************************



/************************************************
 DEBUG helper!
 ************************************************/




@end
