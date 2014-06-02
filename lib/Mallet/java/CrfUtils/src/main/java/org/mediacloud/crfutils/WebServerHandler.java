package org.mediacloud.crfutils;

import java.io.File;
import java.io.IOException;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadFactory;

import com.google.gson.Gson;
import org.simpleframework.http.Request;
import org.simpleframework.http.Response;
import org.simpleframework.http.Status;
import org.simpleframework.http.core.Container;
import org.simpleframework.http.core.ContainerServer;
import org.simpleframework.transport.Server;
import org.simpleframework.transport.connect.Connection;
import org.simpleframework.transport.connect.SocketConnection;

public class WebServerHandler implements Container {

    // Path to test CRF model that is going to be used if no
    // crf.extractorModelPath property has been provided (absolute or relative
    // to lib/Mallet/java/CrfUtils/)
    private final static String TEST_CRF_MODEL_PATH = "src/test/resources/org/mediacloud/crfutils/crf_extractor_model";

    // Server identifier
    private final static String SERVER_IDENTIFIER = "CRFUtils/1.0";

    // Default HTTP port to listen no (if there isn't one set in the configuration)
    private final static int DEFAULT_HTTP_PORT = 8441;

    public static class Task implements Runnable {

        private final Response response;
        private final Request request;
        private static String crfExtractorModelPath;

        // One modelRunner per thread
        private static final ThreadLocal< ModelRunner> threadLocal
                = new ThreadLocal< ModelRunner>() {
                    @Override
                    protected ModelRunner initialValue() {

                        ModelRunner modelRunner;

                        try {
                            System.err.println("Creating new CRF model runner for thread " + Thread.currentThread().getName());
                            modelRunner = new ModelRunner(crfExtractorModelPath);
                        } catch (IOException e) {
                            System.err.println("Unable to initialize CRF model runner: " + e.getMessage());
                            return null;
                        } catch (ClassNotFoundException e) {
                            System.err.println("Unable to find CRF model runner class: " + e.getMessage());
                            return null;
                        }

                        return modelRunner;
                    }
                };

        private final static String dateFormat = "[dd/MMM/yyyy:HH:mm:ss Z]";
        private final static SimpleDateFormat dateFormatter = new SimpleDateFormat(dateFormat);

        public Task(Request request, Response response, String crfExtractorModelPath) {
            this.response = response;
            this.request = request;

            // Not the best pattern around, but the CRF extractor path will
            // remain the same for each Task, so we just (re)set it here
            Task.crfExtractorModelPath = crfExtractorModelPath;
        }

        private static void printAccessLog(Request request, Response response, long responseLength) {

            String referrer = request.getValue("Referrer");
            if (null == referrer || referrer.isEmpty()) {
                referrer = "-";
            }

            StringBuilder logLine = new StringBuilder();
            logLine.append("[").append(Thread.currentThread().getName()).append("] ");
            logLine.append(request.getClientAddress().getHostName());
            logLine.append(" ");
            logLine.append(dateFormatter.format(new Date()));
            logLine.append(" \"");
            logLine.append(request.getMethod()).append(" ");
            logLine.append(request.getPath()).append(" ");
            logLine.append("HTTP/").append(request.getMajor()).append(".").append(request.getMinor());
            logLine.append("\" ");
            logLine.append(response.getStatus().code).append(" ");
            logLine.append(responseLength).append(" ");
            logLine.append("\"").append(referrer).append("\" ");
            logLine.append("\"").append(request.getValue("User-Agent")).append("\"");

            System.out.println(logLine);
        }

        private static String exceptionStackTraceToString(Exception e) {

            StringWriter sw = new StringWriter();
            PrintWriter pw = new PrintWriter(sw);
            e.printStackTrace(pw);
            return sw.toString();
        }

        @Override
        public void run() {

            Gson gson = new Gson();

            try {

                String stringResponse;

                long time = System.currentTimeMillis();
                response.setContentType("text/plain");
                response.setValue("Server", SERVER_IDENTIFIER);
                response.setDate("Date", time);
                response.setDate("Last-Modified", time);

                if (!"POST".equals(request.getMethod())) {
                    response.setStatus(Status.METHOD_NOT_ALLOWED);
                    response.setValue("Allow", "POST");
                    stringResponse = "Not POST.\n";
                } else {

                    String postData = request.getContent();
                    if (null == postData || postData.isEmpty()) {
                        response.setStatus(Status.BAD_REQUEST);
                        stringResponse = "Empty POST.\n";

                    } else {

                        try {

                            ModelRunner modelRunner = threadLocal.get();
                            if (null == modelRunner) {
                                throw new Exception("Unable to initialize CRF model runner.");
                            }

                            ModelRunner.CrfOutput[] crfResults = modelRunner.runModelString(postData);

                            if (null == crfResults) {
                                throw new Exception("CRF processing results are nil.");
                            }

                            response.setStatus(Status.OK);
                            stringResponse = gson.toJson(crfResults);

                        } catch (Exception e) {

                            String errorMessage = "Unable to extract: " + exceptionStackTraceToString(e);

                            response.setStatus(Status.INTERNAL_SERVER_ERROR);

                            //TODO format error as JSON HashMap
                            stringResponse = gson.toJson(errorMessage);
                        }

                    }
                }

                PrintStream body = response.getPrintStream();
                body.print(stringResponse);
                body.close();

                printAccessLog(request, response, stringResponse.getBytes().length);

            } catch (IOException e) {

                String errorMessage = exceptionStackTraceToString(e);
                System.err.println("Request failed: " + errorMessage);
            }
        }
    }

    class SimpleThreadFactory implements ThreadFactory {

        private int counter = 0;
        private final String THREAD_NAME_PREFIX = "http";

        @Override
        public Thread newThread(Runnable r) {
            return new Thread(r, THREAD_NAME_PREFIX + "-" + (counter++));
        }

    }

    private final Executor executor;
    private final SimpleThreadFactory threadFactory;
    private final String crfExtractorModelPath;

    public WebServerHandler(int size, String crfExtractorModelPath) {
        this.threadFactory = new SimpleThreadFactory();
        this.executor = Executors.newFixedThreadPool(size, this.threadFactory);
        this.crfExtractorModelPath = crfExtractorModelPath;
    }

    @Override
    public void handle(Request request, Response response) {

        Task task = new Task(request, response, this.crfExtractorModelPath);

        executor.execute(task);
    }

    public static void main(String[] list) throws Exception {

        String httpListenHost;
        int httpListenPort;

        // Read properties
        String httpListen = System.getProperty("crf.httpListen");
        if (null == httpListen) {
            throw new Exception("crf.httpListen is null.");
        }
        if (httpListen.isEmpty()) {
            httpListen = "0.0.0.0:8441";
        }

        if (httpListen.contains(":")) {
            httpListenHost = httpListen.split(":")[0];
            httpListenPort = Integer.parseInt(httpListen.split(":")[1]);
        } else {
            httpListenHost = httpListen;
            httpListenPort = DEFAULT_HTTP_PORT;
        }

        if (httpListenHost.isEmpty()) {
            throw new Exception("Unable to determine host to listen to from crf.httpListen = " + httpListen);
        }
        if (httpListenPort < 1) {
            throw new Exception("Unable to determine port to listen to from crf.httpListen = " + httpListen);
        }

        String strNumberOfThreads = System.getProperty("crf.numberOfThreads");
        if (null == strNumberOfThreads || strNumberOfThreads.isEmpty()) {
            throw new Exception("crf.numberOfThreads is null or empty.");
        }
        final int numberOfThreads = Integer.parseInt(strNumberOfThreads);
        if (numberOfThreads < 1) {
            throw new Exception("crf.numberOfThreads is below 1.");
        }

        String extractorModelPath = System.getProperty("crf.extractorModelPath");
        if (null == extractorModelPath) {
            System.err.println();
            System.err.println("***");
            System.err.println();
            System.err.println("There was no crf.extractorModelPath property provided,");
            System.err.println("so I will use the test CRF extractor model located at:");
            System.err.println();
            System.err.println("    " + TEST_CRF_MODEL_PATH);
            System.err.println();
            System.err.println("Unless you're starting this web service from a unit test,");
            System.err.println("this might not be exactly what you want.");
            System.err.println();
            System.err.println("Set the crf.extractorModelPath property by running:");
            System.err.println();
            System.err.println("    mvn exec:java -Dcrf.extractorModelPath=path/to/crf_extractor_model");
            System.err.println();
            System.err.println("***");
            System.err.println();

            extractorModelPath = TEST_CRF_MODEL_PATH;
        }

        File f = new File(extractorModelPath);
        if (!(f.exists() && !f.isDirectory())) {
            throw new Exception("Extractor model path does not exist at path: " + extractorModelPath);
        }

        System.err.println("Will listen to " + httpListenHost + ":" + httpListenPort + ".");
        System.err.println("Will spawn " + numberOfThreads + " threads.");
        System.err.println("Will use extractor model located at " + extractorModelPath + ".");

        // Start the CRF model runner web service
        System.err.println("Setting up...");
        Container container = new WebServerHandler(numberOfThreads, extractorModelPath);
        Server server = new ContainerServer(container);
        Connection connection = new SocketConnection(server);
        SocketAddress address = new InetSocketAddress(httpListenHost, httpListenPort);
        System.err.println("Done.");

        connection.connect(address);

        System.err.println("Make POST requests to 127.0.0.1:" + httpListenPort + " with the text you want to run the CRF model against.");
    }

}
